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

  test ".emit enqueues an EmitEventJob with the proper payload" do
    Resque.expects(:enqueue).with(EmitEventJob, event: :deploy, stack_id: @stack.id, payload: {'foo' => 42})
    Hook.emit(:deploy, @stack, {foo: 42})
  end

  test ".deliver schedule a delivery for each matching hook" do
    assert_difference -> { Delivery.count }, +2 do
      Hook.deliver(:deploy, @stack, {'foo' => 42})
    end

    delivery = Delivery.last

    assert_equal @hook.url, delivery.url
    assert_equal 'application/x-www-form-urlencoded', delivery.content_type
    assert_equal 'foo=42', delivery.payload
    assert_equal 'scheduled', delivery.status
  end
end
