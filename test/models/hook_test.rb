# frozen_string_literal: true

require 'test_helper'

module Shipit
  class HookTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @hook = shipit_hooks(:shipit_deploys)
    end

    test "#url must be valid" do
      @hook.delivery_url = 'file:/ad"fa/adfa'
      refute @hook.valid?
      assert_equal ['Delivery url is not a valid URL'], @hook.errors.full_messages
    end

    test "#url must not be localhost" do
      @hook.delivery_url = 'file:///etc/passwd'
      refute @hook.valid?
      assert_equal ['Delivery url is not a valid URL'], @hook.errors.full_messages
    end

    test "#events is accessible as an array" do
      assert_equal %w[deploy rollback], @hook.events
    end

    test "#events can only contain a defined set of values" do
      @hook.events = %w[foo]
      refute @hook.valid?
      assert_equal ["Events is not a strict subset of #{Hook::EVENTS.inspect}"], @hook.errors.full_messages
    end

    test ".deliver schedules a delivery for each matching hook" do
      assert_enqueued_jobs(2, only: DeliverHookJob) do
        Hook.deliver(:deploy, @stack, 'foo' => 42)
      end
    end

    test ".deliver! sends request with correct method, headers, and body" do
      stub_request(:post, @hook.delivery_url).to_return(body: 'OK')
      body = { 'foo' => 42 }
      expected_body = JSON.pretty_generate(body)
      expected_signature = Hook::DeliverySigner.new(@hook.secret).sign(expected_body)

      perform_enqueued_jobs(only: DeliverHookJob) do
        @hook.deliver!(:deploy, body)
      end
      assert_performed_jobs 1
      assert_requested :post, @hook.delivery_url do |req|
        req.headers['X-Shipit-Signature'] == expected_signature
      end
    end

    test ".deliver! sends without signature if no secret is configured" do
      stub_request(:post, @hook.delivery_url).to_return(body: 'OK')
      @hook.update!(secret: '')
      body = { 'foo' => 42 }

      perform_enqueued_jobs(only: DeliverHookJob) do
        @hook.deliver!(:deploy, body)
      end
      assert_performed_jobs 1
      assert_requested :post, @hook.delivery_url do |req|
        !req.headers.key?('X-Shipit-Signature')
      end
    end

    test ".scoped? returns true if the hook has a stack_id" do
      @hook.stack_id = nil
      refute @hook.scoped?

      @hook.stack_id = 42
      assert @hook.scoped?
    end

    test ".emit schedules an EmitEventJob" do
      assert_enqueued_jobs(1, only: EmitEventJob) do
        Hook.emit(:deploy, @stack, 'foo' => 42)
      end
    end

    test ".emit calls #deliver on internal hooks" do
      original_receivers = Shipit.internal_hook_receivers
      FakeReceiver = Module.new
      FakeReceiver.expects(:deliver).with(:deploy, @stack, { 'foo' => 42 })

      Shipit.internal_hook_receivers << FakeReceiver
      Hook.emit(:deploy, @stack, 'foo' => 42)
    ensure
      Shipit.internal_hook_receivers = original_receivers
    end

    test ".emit calls no internal hooks if there are no internal_hook_receivers" do
      original_receivers = Shipit.internal_hook_receivers
      Shipit.internal_hook_receivers = nil
      assert_nothing_raised do
        Hook.emit(:deploy, @stack, 'foo' => 42)
      end
    ensure
      Shipit.internal_hook_receivers = original_receivers
    end

    test ".coerce_payload coerces anonymous user correctly" do
      locked_stack = Stack.first
      locked_stack.lock("Some Reason", nil)
      serialized = Hook.coerce_payload(stack: locked_stack)
      assert_json_document(serialized, "stack.lock_author.anonymous", true)
    end
  end
end
