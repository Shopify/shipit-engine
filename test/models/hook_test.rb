require 'test_helper'

class HookTest < ActiveSupport::TestCase
  setup do
    @stack = stacks(:shipit)
    @hook = hooks(:shipit_deploys)
  end

  test "#url must be valid" do
    @hook.url = 'file:///etc/passwd'
    refute @hook.valid?
    assert_equal ['Url is not a valid URL'], @hook.errors.full_messages
  end

  test "#events is accessible as an array" do
    assert_equal %w(deploy rollback), @hook.events
  end

  test "#events can only contain a defined set of values" do
    @hook.events = %w(foo)
    refute @hook.valid?
    assert_equal ["Events is not a strict subset of #{Hook::EVENTS.inspect}"], @hook.errors.full_messages
  end

  test ".emit enqueues an EmitEventJob with the proper payload" do
    assert_enqueued_with(job: EmitEventJob) do
      Hook.emit(:deploy, @stack, foo: 42)
    end
  end

  test ".deliver schedule a delivery for each matching hook" do
    assert_difference -> { Delivery.count }, +2 do
      Hook.deliver(:deploy, @stack, 'foo' => 42)
    end

    delivery = Delivery.last

    assert_equal @hook.url, delivery.url
    assert_equal 'application/x-www-form-urlencoded', delivery.content_type
    assert_equal 'foo=42', delivery.payload
    assert_equal 'scheduled', delivery.status
  end

  test ".scoped? returns true if the hook have a stack_id" do
    @hook.stack_id = nil
    refute @hook.scoped?

    @hook.stack_id = 42
    assert @hook.scoped?
  end
end
