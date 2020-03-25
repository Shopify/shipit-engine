# typed: false
require 'test_helper'

module Shipit
  class RefreshStatusesJobTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @job = RefreshStatusesJob.new
    end

    test "#perform call #refresh_statuses! on the last 30 commits of the stack" do
      Commit.any_instance.expects(:refresh_statuses!).times(@stack.commits.count)

      @job.perform(stack_id: @stack.id)
    end

    test "if :commit_id param is present only this commit is refreshed" do
      Commit.any_instance.expects(:refresh_statuses!).once

      @job.perform(stack_id: @stack.id, commit_id: shipit_commits(:first).id)
    end
  end
end
