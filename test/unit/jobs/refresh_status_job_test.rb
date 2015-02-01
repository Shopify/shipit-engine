require 'test_helper'

class RefreshStatusesJobTest < ActiveSupport::TestCase
  setup do
    @stack = stacks(:shipit)
    @job = RefreshStatusesJob
  end

  test "#perform call #refresh_status on the last 30 commits of the stack" do
    Commit.any_instance.expects(:refresh_statuses).times(@stack.commits.count)

    @job.perform(stack_id: @stack.id)
  end

  test "if :commit_id param is present only this commit is refreshed" do
    Commit.any_instance.expects(:refresh_statuses).once

    @job.perform(stack_id: @stack.id, commit_id: commits(:first).id)
  end
end
