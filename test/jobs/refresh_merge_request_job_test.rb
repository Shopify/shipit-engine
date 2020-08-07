# frozen_string_literal: true

require "test_helper"

module Shipit
  class RefreshMergeRequestJobTest < ActiveSupport::TestCase
    test "perform refreshes the pull request" do
      merge_request = shipit_merge_requests(:shipit_pending)
      merge_request.expects(:refresh!).once

      job.perform(merge_request)
    end

    test "En-queues a merge pull request job for the PR's stack" do
      merge_request = shipit_merge_requests(:shipit_pending)
      merge_request.stubs(:refresh!)

      assert_enqueued_with(job: ProcessMergeRequestsJob, args: [merge_request.stack]) do
        job.perform(merge_request)
      end
    end

    test "Raises if the merge_request's stack hasn't yet synced commits with Github" do
      merge_request = shipit_merge_requests(:shipit_pending)
      merge_request.stubs(:refresh!)
      merge_request.stack.commits.clear

      assert_raises(Stack::NotYetSynced) do
        job.perform(merge_request)
      end
    end

    def job
      RefreshMergeRequestJob.new
    end
  end
end
