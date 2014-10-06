require 'test_helper'

class RefreshStatusesJobTest < ActiveSupport::TestCase
  setup do
    @stack = stacks(:shipit)
    @job = RefreshStatusesJob.new
  end

  test "#perform call #refresh_status on the last 30 commits of the stack" do
    Commit.any_instance.expects(:refresh_statuses).times(@stack.commits.count)

    @job.perform(stack_id: @stack.id)
  end

end
