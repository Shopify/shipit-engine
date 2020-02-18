# frozen_string_literal: true

require "test_helper"

module Shipit
  class RefreshPullRequestJobTest < ActiveSupport::TestCase
    test "perform refreshes the pull request" do
      pull_request = shipit_pull_requests(:shipit_pending)
      pull_request.expects(:refresh!).once

      job.perform(pull_request)
    end

    test "En-queues a merge pull request job for the PR's stack" do
      pull_request = shipit_pull_requests(:shipit_pending)
      pull_request.stubs(:refresh!)

      assert_enqueued_with(job: MergePullRequestsJob, args: [pull_request.stack]) do
        job.perform(pull_request)
      end
    end

    test "Raises if the pull_request's stack hasn't yet synced commits with Github" do
      pull_request = shipit_pull_requests(:shipit_pending)
      pull_request.stubs(:refresh!)
      pull_request.stack.commits.clear

      assert_raises(Stack::NotYetSynced) do
        job.perform(pull_request)
      end
    end

    def job
      RefreshPullRequestJob.new
    end
  end
end
