require 'test_helper'

class EmitEventJobTest < ActiveSupport::TestCase
  setup do
    @stack = stacks(:shipit)
    @job = EmitEventJob.new
  end

  test "#perform schedule deliveries" do
    assert_difference -> { Delivery.scheduled.count }, 2 do
      @job.perform(event: :deploy, stack_id: @stack.id, payload: {foo: 42}.to_json)
    end
  end
end
