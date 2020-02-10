require 'test_helper'

module Shipit
  class RefreshPullRequestJobTest < ActiveSupport::TestCase
    setup do
      @job = RefreshPullRequestJob.new
    end

    test "#perform call #refresh! pull_request and schedule a merge when a merge request" do
      pull_request = shipit_pull_requests(:shipit_pending)

      PullRequest.any_instance.expects(:refresh!)

      assert_enqueued_with(job: MergePullRequestsJob) do
        @job.perform(pull_request)
      end
    end

    test "#perform call #refresh! pull_request does not schedule a merge when not a merge request" do
      pull_request = shipit_pull_requests(:shipit_assigned)

      PullRequest.any_instance.expects(:refresh!)

      assert_no_enqueued_jobs do
        @job.perform(pull_request)
      end
    end
  end
end
