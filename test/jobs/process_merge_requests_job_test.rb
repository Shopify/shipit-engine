# frozen_string_literal: true

require 'test_helper'

module Shipit
  class ProcessMergeRequestsJobTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @job = ProcessMergeRequestsJob.new

      @pending_pr = shipit_merge_requests(:shipit_pending)
      @unmergeable_pr = shipit_merge_requests(:shipit_pending_unmergeable)
      @not_ready_pr = shipit_merge_requests(:shipit_pending_not_mergeable_yet)
      @closed_pr = shipit_merge_requests(:shipit_pending_closed)
      @merged_pr = shipit_merge_requests(:shipit_pending_merged)
      @expired_pr = shipit_merge_requests(:shipit_pending_expired)
      @mergable_pending_ci = shipit_merge_requests(:shipit_mergeable_pending_ci)
    end

    test "#perform rejects unmergeable PRs and merge the others" do
      MergeRequest.any_instance.stubs(:refresh!)
      stub_request(:put, "#{@pending_pr.api_url}/merge").to_return(status: %w(200 OK), body: {
        sha: "6dcb09b5b57875f334f61aebed695e2e4193db5e",
        merged: true,
        message: "Pull Request successfully merged",
      }.to_json)
      branch_url = "https://api.github.com/repos/shopify/shipit-engine/git/refs/heads/feature-62"
      stub_request(:delete, branch_url).to_return(status: %w(204 No content))
      pulls_url = "https://api.github.com/repos/shopify/shipit-engine/pulls?base=feature-62"
      stub_request(:get, pulls_url).to_return(status: %w(200 OK), body: '[]')

      @job.perform(@stack)

      assert_predicate @pending_pr.reload, :merged?
      assert_predicate @unmergeable_pr.reload, :rejected?
    end

    test "#perform rejects PRs if the merge attempt fails" do
      MergeRequest.any_instance.stubs(:refresh!)
      stub_request(:put, "#{@pending_pr.api_url}/merge").to_return(status: %w(405 Method not allowed), body: {
        message: "Pull Request is not mergeable",
        documentation_url: "https://developer.github.com/v3/pulls/#merge-a-pull-request-merge-button",
      }.to_json)

      @job.perform(@stack)

      assert_predicate @pending_pr.reload, :rejected?
    end

    test "#perform rejects PRs but do not attempt to merge any if the stack doesn't allow merges" do
      MergeRequest.any_instance.stubs(:refresh!)
      @stack.update!(lock_reason: 'Maintenance')
      @job.perform(@stack)
      assert_predicate @pending_pr.reload, :pending?
    end

    test "#perform revalidate PRs but do not attempt to merge any if the stack doesn't allow merges" do
      MergeRequest.any_instance.stubs(:refresh!)
      @stack.update!(lock_reason: 'Maintenance')
      @job.perform(@stack)
      assert_predicate @expired_pr.reload, :revalidating?
    end

    test "#perform schedules a new job if the first PR in the queue is not mergeable yet" do
      MergeRequest.any_instance.stubs(:refresh!)

      @pending_pr.update!(mergeable: nil)
      assert_enqueued_with(job: ProcessMergeRequestsJob) do
        @job.perform(@stack)
      end
      assert_predicate @pending_pr.reload, :pending?
    end

    test "#perform cancels merge requests for closed PRs" do
      @pending_pr.cancel!
      MergeRequest.any_instance.stubs(:refresh!)
      @job.perform(@stack)
      assert_predicate @closed_pr.reload, :canceled?
    end

    test "#perform cancels merge requests for manually merged PRs" do
      @pending_pr.cancel!
      MergeRequest.any_instance.stubs(:refresh!)
      @job.perform(@stack)
      assert_predicate @merged_pr.reload, :canceled?
    end

    test "#perform does not reject pull requests with pending statuses" do
      @pending_pr.cancel!
      MergeRequest.any_instance.stubs(:refresh!)
      @job.perform(@stack)
      refute_predicate @mergable_pending_ci.reload, :rejected?
      refute_predicate @mergable_pending_ci.reload, :merged?
    end
  end
end
