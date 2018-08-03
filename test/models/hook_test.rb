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
      assert_equal %w(deploy rollback), @hook.events
    end

    test "#events can only contain a defined set of values" do
      @hook.events = %w(foo)
      refute @hook.valid?
      assert_equal ["Events is not a strict subset of #{Hook::EVENTS.inspect}"], @hook.errors.full_messages
    end

    test ".deliver schedules a delivery for each matching hook" do
      assert_enqueued_jobs(2, only: DeliverHookJob) do
        Hook.deliver(:deploy, @stack, 'foo' => 42)
      end
    end

    test ".scoped? returns true if the hook has a stack_id" do
      @hook.stack_id = nil
      refute @hook.scoped?

      @hook.stack_id = 42
      assert @hook.scoped?
    end
  end
end
