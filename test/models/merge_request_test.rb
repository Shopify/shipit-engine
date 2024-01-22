# frozen_string_literal: true

require 'test_helper'

module Shipit
  class MergeRequestTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @pr = shipit_merge_requests(:shipit_pending)
      @user = shipit_users(:walrus)
    end

    test ".request_merge! creates a record and schedule a refresh" do
      merge_request = nil
      assert_enqueued_with(job: RefreshMergeRequestJob) do
        merge_request = MergeRequest.request_merge!(@stack, 64, @user)
      end
      assert_predicate merge_request, :persisted?
    end

    test ".request_merge! only track pull requests once" do
      assert_difference -> { MergeRequest.count }, +1 do
        5.times { MergeRequest.request_merge!(@stack, 999, @user) }
      end
    end

    test ".request_merge! retry canceled pull requests" do
      original_merge_requested_at = @pr.merge_requested_at
      @pr.cancel!
      assert_predicate @pr, :canceled?
      MergeRequest.request_merge!(@stack, @pr.number, @user)
      assert_predicate @pr.reload, :pending?
      assert_not_equal original_merge_requested_at, @pr.merge_requested_at
      assert_in_delta Time.now.utc, @pr.merge_requested_at, 2
    end

    test ".request_merge! retry rejected pull requests" do
      original_merge_requested_at = @pr.merge_requested_at
      @pr.reject!('merge_conflict')
      assert_predicate @pr, :rejected?
      MergeRequest.request_merge!(@stack, @pr.number, @user)
      assert_predicate @pr.reload, :pending?
      assert_not_equal original_merge_requested_at, @pr.merge_requested_at
      assert_in_delta Time.now.utc, @pr.merge_requested_at, 2
      assert_nil @pr.rejection_reason
    end

    test ".request_merge! retry revalidating pull requests but keep the original request time" do
      original_merge_requested_at = @pr.merge_requested_at
      @pr.revalidate!
      assert_predicate @pr, :revalidating?
      MergeRequest.request_merge!(@stack, @pr.number, @user)
      assert_predicate @pr.reload, :pending?
      assert_equal original_merge_requested_at, @pr.merge_requested_at
    end

    test ".extract_number can get a pull request number from different formats" do
      assert_equal 42, MergeRequest.extract_number(@stack, '42')
      assert_equal 42, MergeRequest.extract_number(@stack, '#42')
      assert_equal 42, MergeRequest.extract_number(@stack, 'https://github.com/Shopify/shipit-engine/pull/42')

      assert_nil MergeRequest.extract_number(@stack, 'https://github.com/ACME/shipit-engine/pull/42')

      Shipit.github.class.any_instance.expects(:domain).returns('github.acme.com').at_least_once
      assert_equal 42, MergeRequest.extract_number(@stack, 'https://github.acme.com/Shopify/shipit-engine/pull/42')
      assert_nil MergeRequest.extract_number(@stack, 'https://github.com/Shopify/shipit-engine/pull/42')
    end

    test "refresh! pulls state from GitHub" do
      merge_request = shipit_merge_requests(:shipit_fetching)

      head_sha = '64b3833d39def7ec65b57b42f496eb27ab4980b6'
      base_sha = 'ba7ab50e02286f7d6c60c1ef75258133dd9ea763'
      Shipit.github.api.expects(:pull_request).with(@stack.github_repo_name, merge_request.number).returns(
        stub(
          id: 4_857_578,
          url: 'https://api.github.com/repos/Shopify/shipit-engine/pulls/64',
          title: 'Great feature',
          state: 'open',
          mergeable: true,
          additions: 24,
          deletions: 5,
          merged_at: nil,
          head: stub(
            ref: 'super-branch',
            sha: head_sha,
          ),
          base: stub(
            ref:  'default-branch',
            sha: base_sha,
          ),
        ),
      )

      author = stub(
        id: 1234,
        login: 'bob',
        name: 'Bob the Builder',
        email: 'bob@bob.com',
      )

      [head_sha, base_sha].each do |sha|
        Shipit.github.api.expects(:commit).with(@stack.github_repo_name, sha).returns(
          stub(
            sha: sha,
            author: author,
            committer: author,
            commit: stub(
              message: 'Great feature',
              author: stub(date: 1.day.ago),
              committer: stub(date: 1.day.ago),
            ),
            stats: stub(
              additions: 24,
              deletions: 5,
            ),
          ),
        )
      end

      Shipit.github.api.expects(:statuses).with(@stack.github_repo_name, head_sha, per_page: 100).returns([stub(
        state: 'success',
        description: nil,
        context: 'default',
        target_url: 'http://example.com',
        created_at: 1.day.ago,
      )])

      Shipit.github.api.expects(:check_runs).with(@stack.github_repo_name, head_sha).returns(stub(
        check_runs: [stub(
          id: 123456,
          name: 'check run',
          conclusion: 'success',
          output: stub(
            title: 'a test checkrun',
          ),
          details_url: 'http://example.com',
          html_url: 'http://example.com',
          completed_at: Time.now,
          started_at: 1.minute.ago,
        )],
      ))

      merge_request.refresh!

      assert_predicate merge_request, :mergeable?
      assert_predicate merge_request, :pending?
      assert_equal 'super-branch', merge_request.branch

      assert_not_nil merge_request.head
      assert_predicate merge_request.head, :detached?
      assert_predicate merge_request.head, :success?
    end

    test "#reject! records the reason" do
      @pr.reject!('merge_conflict')
      assert_equal 'merge_conflict', @pr.rejection_reason
    end

    test "transitionning from rejected to any other state clear the rejection reason" do
      @pr.reject!('merge_conflict')
      assert_equal 'merge_conflict', @pr.rejection_reason
      @pr.retry!
      assert_nil @pr.rejection_reason
      assert_nil @pr.reload.rejection_reason
    end

    test "#reject_unless_mergeable! returns `false` if the PR is not yet mergeable" do
      @pr.update!(mergeable: nil)
      assert_predicate @pr, :not_mergeable_yet?
      assert_equal false, @pr.reject_unless_mergeable!
      assert_predicate @pr, :pending?
    end

    test "#reject_unless_mergeable! rejects the PR if it has a merge conflict" do
      @pr.update!(mergeable: false)

      assert_predicate @pr, :merge_conflict?
      assert_equal true, @pr.reject_unless_mergeable!
      assert_predicate @pr, :rejected?
      assert_equal 'merge_conflict', @pr.rejection_reason
    end

    test "#reject_unless_mergeable! rejects the PR if it has a failing CI status" do
      @pr.head.statuses.create!(stack: @pr.stack, state: 'failure', context: 'ci/circle')

      refute_predicate @pr, :all_status_checks_passed?
      assert_predicate @pr, :any_status_checks_failed?
      assert_equal true, @pr.reject_unless_mergeable!
      assert_predicate @pr, :rejected?
      assert_equal 'ci_failing', @pr.rejection_reason
    end

    test "#reject_unless_mergeable! does not reject the PR if it has a pending CI status" do
      @pr.head.statuses.create!(stack: @pr.stack, state: 'pending', context: 'ci/circle')

      refute_predicate @pr, :all_status_checks_passed?
      refute_predicate @pr, :any_status_checks_failed?
      assert_equal false, @pr.reject_unless_mergeable!
      refute_predicate @pr, :rejected?
    end

    test "#reject_unless_mergeable! reject the PR if it has a missing required CI status" do
      @pr.stack.cached_deploy_spec.stubs(:required_statuses).returns(['ci/circle'])
      @pr.head.statuses.where(context: 'ci/circle').delete_all

      refute_predicate @pr, :all_status_checks_passed?
      refute_predicate @pr, :any_status_checks_failed?
      assert_predicate @pr, :any_status_checks_missing?
      assert_equal true, @pr.reject_unless_mergeable!
      assert_predicate @pr, :rejected?
      assert_equal 'ci_missing', @pr.rejection_reason
    end

    test "#reject_unless_mergeable! reject the PR if it has a missing CI status (multi-status)" do
      @pr.stack.cached_deploy_spec.stubs(:required_statuses).returns(['ci/circle'])
      @pr.head.statuses.where(context: 'ci/circle').delete_all
      @pr.head.statuses.create!(stack: @pr.stack, state: 'success', context: 'ci/travis')

      refute_predicate @pr, :all_status_checks_passed?
      refute_predicate @pr, :any_status_checks_failed?
      assert_predicate @pr, :any_status_checks_missing?
      assert_equal true, @pr.reject_unless_mergeable!
      assert_predicate @pr, :rejected?
      assert_equal 'ci_missing', @pr.rejection_reason
    end

    test "#reject_unless_mergeable! rejects the PR if it is stale" do
      @pr.stubs(:stale?).returns(true)
      assert_equal true, @pr.reject_unless_mergeable!
      assert_predicate @pr, :rejected?
      assert_equal 'requires_rebase', @pr.rejection_reason
    end

    test "#merge! raises a MergeRequest::NotReady if the PR isn't mergeable yet" do
      @pr.update!(mergeable: nil)

      assert_predicate @pr, :not_mergeable_yet?
      assert_raises MergeRequest::NotReady do
        @pr.merge!
      end
      @pr.reload
      assert_predicate @pr, :pending?
    end

    test "status transitions emit hooks" do
      job = assert_enqueued_with(job: EmitEventJob) do
        @pr.reject!('merge_conflict')
      end
      params = job.arguments.first
      assert_equal 'merge', params[:event]
      assert_json_document params[:payload], 'status', 'rejected'
      assert_json_document params[:payload], 'merge_request.rejection_reason', 'merge_conflict'
      assert_json_document params[:payload], 'merge_request.number', @pr.number
    end

    test "#merge! doesnt delete the branch if there are open PRs against it" do
      Shipit.github.api.expects(:merge_pull_request).once.returns(true)
      Shipit.github.api.expects(:pull_requests).once.with(@stack.github_repo_name, base: @pr.branch).returns([1])
      Shipit.github.api.expects(:delete_branch).never.returns(false)
      assert_equal true, @pr.merge!
    end

    test "#merge! increments undeployed_commits_count" do
      Shipit.github.api.expects(:merge_pull_request).once.returns(true)
      Shipit.github.api.expects(:pull_requests).once.returns([])
      Shipit.github.api.expects(:delete_branch).once.returns(true)
      assert_difference '@stack.undeployed_commits_count' do
        @pr.merge!
        @stack.reload
      end
    end

    test "#all_status_checks_passed? returns false when head commit is unknown" do
      @pr.update(head_id: nil)
      refute_predicate @pr, :all_status_checks_passed?
    end

    test "#stale? returns false by default" do
      refute_predicate @pr, :stale?
    end

    test "#stale? returns true when the branch falls behind the maximum commits" do
      @pr.base_commit = shipit_commits(:second)
      @pr.base_ref = 'default-branch'
      Shipit.github.api.expects(:compare).with(@stack.github_repo_name, @pr.base_ref, @pr.head.sha).returns(
        stub(
          behind_by: 10,
        ),
      )
      spec = { 'merge' => { 'max_divergence' => { 'commits' => 1 } } }
      @pr.stack.cached_deploy_spec = DeploySpec.new(spec)
      assert_predicate @pr, :stale?
    end

    test "#stale? returns true when the branch falls behind the maximum age" do
      @pr.base_commit = shipit_commits(:second)
      @pr.head.committed_at = 2.hours.ago
      spec = { 'merge' => { 'max_divergence' => { 'age' => '1h' } } }
      @pr.stack.cached_deploy_spec = DeploySpec.new(spec)
      assert_predicate @pr, :stale?
    end

    test "#stale? is false when base_commit information is missing" do
      @pr.base_commit = nil
      spec = { 'merge' => { 'max_divergence' => { 'age' => '1h', 'commits' => 10 } } }
      @pr.stack.cached_deploy_spec = DeploySpec.new(spec)
      refute_predicate @pr, :stale?
    end
  end
end
