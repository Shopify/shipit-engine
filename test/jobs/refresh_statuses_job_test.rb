# frozen_string_literal: true
require 'test_helper'

module Shipit
  class RefreshStatusesJobTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @job = RefreshStatusesJob.new
    end

    test "#perform enqueues RefreshStatusesJob for the last 30 commits on the stack" do
      assert_enqueued_jobs @stack.commits.count, only: RefreshStatusesJob do
        @job.perform(stack_id: @stack.id)
      end
    end

    test "if :commit_id param is present only this commit is refreshed" do
      Commit.any_instance.expects(:refresh_statuses!).once

      @job.perform(stack_id: @stack.id, commit_id: shipit_commits(:first).id)
    end
  end
end
