require 'test_helper'

module Shipit
  class CommitsTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @pr = @stack.commits.new
      @pr.message = "Merge pull request #31 from Shopify/improve-polling\n\nSeveral improvements to polling"
      @stack.reload
      @commit = shipit_commits(:first)
    end

    test "#pull_request? detect pull request based on message format" do
      assert @pr.pull_request?
      refute @commit.pull_request?
    end

    test "#pull_request? detects pull requests with unusual branch names" do
      @pr.message = "Merge pull request #7 from Shopify/bump-👉-v1.0.1\n\nBump 👉 v1.0.1"
      assert @pr.pull_request?
      assert_equal "Bump 👉 v1.0.1", @pr.pull_request_title
    end

    test "#pull_request_number extract the pull request id from the message" do
      assert_equal 31, @pr.pull_request_number
      assert_nil @commit.pull_request_number
    end

    test "#pull_request_title extract the pull request title from the message" do
      assert_equal 'Several improvements to polling', @pr.pull_request_title
      assert_nil @commit.pull_request_title
    end

    test "#newer_than(nil) returns all commits" do
      assert_equal @stack.commits.all.to_a, @stack.commits.newer_than(nil).to_a
    end

    test "updating to detached broadcasts an update event" do
      expect_event(@stack)
      @commit.update(detached: true)
    end

    test ".detach! detaches commits" do
      parent = shipit_commits(:fourth)
      child = shipit_commits(:fifth)
      refute child.detached?, "fifth commit should not be detached"

      parent.detach_children!

      assert child.reload.detached?, "children commits must be detached"
    end

    test "#destroy broadcasts an update event" do
      expect_event(@stack)
      @commit.destroy
    end

    test "updating broadcasts an update event" do
      expect_event(@stack)
      @commit.update_attributes(message: "toto")
    end

    test "updating state to success triggers new deploy when stack has continuous deployment" do
      @stack.reload.update(continuous_deployment: true)
      @stack.deploys.destroy_all

      assert_difference "Deploy.count" do
        assert_enqueued_with(job: ContinuousDeliveryJob, args: [@stack]) do
          @stack.commits.last.statuses.create!(stack_id: @stack.id, state: 'success', context: 'ci/travis')
        end
        ContinuousDeliveryJob.new.perform(@stack)
      end
    end

    test "updating state to success skips deploy when stack has CD but a deploy is in progress" do
      @stack.reload.update(continuous_deployment: true)
      @stack.trigger_deploy(@commit, @commit.committer)

      assert_no_difference "Deploy.count" do
        @commit.statuses.create!(stack_id: @stack.id, state: 'success', context: 'ci/travis')
      end
    end

    test "updating state to success skips deploy when stack has CD but the stack is locked" do
      @stack.deploys.destroy_all
      @stack.reload.update!(continuous_deployment: true, lock_reason: "Maintenance ongoing")

      assert_no_difference "Deploy.count" do
        @commit.statuses.create!(stack_id: @stack.id, state: 'success', context: 'ci/travis')
      end
    end

    test "updating won't trigger a deploy if a newer commit has been deployed" do
      @stack.reload.update(continuous_deployment: true)
      @stack.deploys.destroy_all

      walrus = shipit_users(:walrus)
      new_commit = @stack.commits.create!(
        sha: '1234',
        message: 'bla',
        author: walrus,
        committer: walrus,
        authored_at: Time.now,
        committed_at: Time.now,
      )

      @stack.deploys.create!(
        user_id: walrus.id,
        since_commit: @stack.commits.first,
        until_commit: new_commit,
        status: 'success',
      )

      assert_no_difference "Deploy.count" do
        @commit.statuses.create!(stack_id: @stack.id, state: 'success')
      end
    end

    test "updating won't trigger a deploy if this commit has already been deployed" do
      @stack.reload.update!(continuous_deployment: true)

      assert_no_difference "Deploy.count" do
        @stack.last_deployed_commit.statuses.create!(stack_id: @stack.id, state: 'success')
      end
    end

    test "updating without CD skips deploy regardless of state" do
      @stack.reload.deploys.destroy_all

      assert_no_difference "Deploy.count" do
        @commit.statuses.create!(stack_id: @stack.id, state: 'success')
      end
    end

    test "updating when not success does not schedule CD" do
      @stack.reload.update(continuous_deployment: true)
      @stack.deploys.destroy_all

      assert_no_difference "Deploy.count" do
        @commit.statuses.create!(stack_id: @stack.id, state: 'failure')
      end
    end

    test "creating broadcasts an update event" do
      expect_event(@stack)
      walrus = shipit_users(:walrus)
      @stack.commits.create(
        author: walrus,
        committer: walrus,
        sha: "ab12",
        authored_at: DateTime.now,
        committed_at: DateTime.now,
        message: "more fish!",
      )
    end

    test "refresh_statuses! pull state from github" do
      status = mock(
        state: 'success',
        description: nil,
        context: 'default',
        target_url: 'http://example.com',
        created_at: 1.day.ago,
      )
      Shipit.github_api.expects(:statuses).with(@stack.github_repo_name, @commit.sha).returns([status])
      assert_difference '@commit.statuses.count', 1 do
        @commit.refresh_statuses!
      end
      assert_equal 'success', @commit.statuses.first.state
    end

    test "#creating a commit update the undeployed_commits_count" do
      walrus = shipit_users(:walrus)
      assert_equal 1, @stack.undeployed_commits_count
      @stack.commits.create!(
        author: walrus,
        committer: walrus,
        sha: "ab12",
        authored_at: DateTime.now,
        committed_at: DateTime.now,
        message: "more fish!",
      )
      @stack.reload
      assert_equal 2, @stack.undeployed_commits_count
    end

    test "fetch_stats! pulls additions and deletions from github" do
      commit = stub(stats: stub(additions: 4242, deletions: 2424))
      Shipit.github_api.expects(:commit).with(@stack.github_repo_name, @commit.sha).returns(commit)
      @commit.fetch_stats!
      assert_equal 4242, @commit.additions
      assert_equal 2424, @commit.deletions
    end

    test "fetch_stats! doesn't fail if the commits have no stats" do
      commit = stub(stats: nil)
      Shipit.github_api.expects(:commit).with(@stack.github_repo_name, @commit.sha).returns(commit)
      assert_nothing_raised do
        @commit.fetch_stats!
      end
    end

    test ".by_sha! can match sha prefixes" do
      assert_equal @commit, Commit.by_sha!(@commit.sha[0..7])
    end

    test ".by_sha! raises on ambigous sha prefixes" do
      assert_raises Commit::AmbiguousRevision do
        Commit.by_sha!(@commit.sha[0..3])
      end
    end

    test "#creating a commit for new stack updates last_deployed_at to nil" do
      walrus = shipit_users(:walrus)
      stack = shipit_stacks(:undeployed_stack)
      stack.commits.create!(
        author: walrus,
        committer: walrus,
        sha: "ab12",
        authored_at: DateTime.now,
        committed_at: DateTime.now,
        message: "more fish!",
      )
      stack.reload
      assert_nil stack.last_deployed_at
    end

    test ".by_sha! raises if the sha prefix matches multiple commits" do
      clone = Commit.new(@commit.attributes.except('id'))
      clone.sha[8..-1] = 'abc12'
      clone.save!

      assert_raises Commit::AmbiguousRevision do
        Commit.by_sha!(@commit.sha[0..7])
      end
    end

    test "#state is `unknown` by default" do
      assert_equal 'unknown', @stack.commits.new.state
    end

    test "#state is `success` if all most recent the statuses are `success`" do
      assert_equal 'success', shipit_commits(:third).state
    end

    test "#state is `failure` one of the most recent the statuses is `failure`" do
      assert_equal 'failure', shipit_commits(:second).state
    end

    test "#state is `pending` one of the most recent the statuses is `pending` and none is `failure` or `error`" do
      assert_equal 'pending', shipit_commits(:fourth).state
    end

    test "#state doesn't consider statuses that are hidden or allowed to fail" do
      assert_equal 'pending', @commit.state

      @commit.statuses.create!(stack_id: @stack.id, context: 'metrics/coveralls', state: 'failure')
      @commit.statuses.create!(stack_id: @stack.id, context: 'metrics/performance', state: 'failure')
      assert_equal 'failure', @commit.reload.state

      @commit.stack.update!(cached_deploy_spec: DeploySpec.new('ci' => {
        'hide' => 'metrics/coveralls',
        'allow_failures' => 'metrics/performance',
      }))
      assert_equal 'pending', @commit.reload.state
    end

    test "#status returns an unknown if the commit has no statuses" do
      commit = shipit_commits(:second)
      commit.statuses = []
      assert_predicate commit.status, :unknown?
    end

    test "#status rejects the statuses that are specified in the deploy spec's `ci.hide`" do
      commit = shipit_commits(:second)
      assert_predicate commit.status, :group?
      assert_equal 2, commit.status.size
      commit.stack.update!(cached_deploy_spec: DeploySpec.new('ci' => {'hide' => 'metrics/coveralls'}))
      commit.reload
      refute_predicate commit.status, :group?
    end

    test "#deployable? is true if commit status is 'success'" do
      assert_predicate shipit_commits(:cyclimse_first), :deployable?
    end

    test "#deployable? is true if stack is set to 'ignore_ci'" do
      commit = shipit_commits(:first)
      commit.stack.update!(ignore_ci: true)
      assert_predicate commit, :deployable?
    end

    test "#deployable? is false if commit has no statuses" do
      refute_predicate shipit_commits(:fifth), :deployable?
    end

    test "#deployable? is false if commit is locked" do
      commit = shipit_commits(:cyclimse_first)
      commit.update!(locked: true)
      refute_predicate commit, :deployable?
    end

    test "#deployable? is false if a required status is missing" do
      commit = shipit_commits(:cyclimse_first)
      commit.stack.stubs(:required_statuses).returns(%w(ci/very-important))
      refute_predicate commit, :deployable?
    end

    expected_webhook_transitions = { # we expect deployable_status to fire on these transitions, and not on any others
      'unknown' => %w(pending success failure error),
      'pending' => %w(success failure error),
      'success' => %w(failure error),
      'failure' => %w(success),
      'error' => %w(success),
    }
    expected_webhook_transitions.each do |initial_state, firing_states|
      initial_status_attributes = {state: initial_state, description: 'abc', context: 'ci/travis'}
      (expected_webhook_transitions.keys - %w(unknown)).each do |new_state|
        should_fire = firing_states.include?(new_state)
        action = should_fire ? 'fires' : 'does not fire'
        test "#add_status #{action} for status from #{initial_state} to #{new_state}" do
          commit = shipit_commits(:cyclimse_first)
          assert commit.stack.hooks.where(events: ['deploy_status']).size >= 1
          refute commit.stack.ignore_ci
          commit.statuses.destroy_all
          commit.reload
          unless initial_state == 'unknown'
            attrs = initial_status_attributes.merge(
              stack_id: commit.stack_id,
              created_at: 10.days.ago.to_s(:db),
            )
            commit.statuses.create!(attrs)
          end
          assert_equal initial_state, commit.state

          expected_status_attributes = {state: new_state, description: initial_state, context: 'ci/travis'}
          add_status = lambda do
            attrs = expected_status_attributes.merge(created_at: 1.day.ago.to_s(:db))
            commit.create_status_from_github!(OpenStruct.new(attrs))
          end
          expect_hook_emit(commit, :commit_status, expected_status_attributes) do
            if should_fire
              expect_hook_emit(commit, :deployable_status, expected_status_attributes, &add_status)
            else
              expect_no_hook(:deployable_status, &add_status)
            end
          end
        end
      end
    end

    test "#add_status does not fire webhooks for invisible statuses" do
      @stack.deploys_and_rollbacks.destroy_all
      commit = shipit_commits(:second)
      assert commit.stack.hooks.where(events: ['commit_status']).size >= 1
      refute_predicate commit, :deployed?

      expect_no_hook(:deployable_status) do
        github_status = OpenStruct.new(
          state: 'failure',
          description: 'Sad',
          context: 'ci/hidden',
          created_at: 1.day.ago.to_s(:db),
        )
        commit.create_status_from_github!(github_status)
      end
    end

    test "#add_status does not fire webhooks for non-meaningful statuses" do
      @stack.deploys_and_rollbacks.destroy_all
      commit = shipit_commits(:second)
      assert commit.stack.hooks.where(events: ['commit_status']).size >= 1
      refute_predicate commit, :deployed?

      expect_no_hook(:deployable_status) do
        github_status = OpenStruct.new(
          state: 'failure',
          description: 'Sad',
          context: 'ci/ok_to_fail',
          created_at: 1.day.ago.to_s(:db),
        )
        commit.create_status_from_github!(github_status)
      end
    end

    test "#add_status does not fire webhooks for already deployed commits" do
      commit = shipit_commits(:second)
      assert_predicate commit, :deployed?

      expect_no_hook(:deployable_status) do
        github_status = OpenStruct.new(
          state: 'failure',
          description: 'Sad',
          context: 'ci/travis',
          created_at: 1.day.ago.to_s(:db),
        )
        commit.create_status_from_github!(github_status)
      end
    end

    test "#add_status schedule a MergePullRequests job if the commit transition to `pending` or `success`" do
      commit = shipit_commits(:second)
      github_status = OpenStruct.new(
        state: 'success',
        description: 'Cool',
        context: 'metrics/coveralls',
        created_at: 1.day.ago.to_s(:db),
      )

      assert_equal 'failure', commit.state
      assert_enqueued_with(job: MergePullRequestsJob, args: [@commit.stack]) do
        commit.create_status_from_github!(github_status)
        assert_equal 'success', commit.state
      end
    end

    test "#status hierarchy uses failures and errors, then pending, then successes, then Status::Unknown" do
      commit = shipit_commits(:first)
      pending = commit.statuses.new(stack_id: @stack.id, state: 'pending', context: 'ci/pending')
      failure = commit.statuses.new(stack_id: @stack.id, state: 'failure', context: 'ci/failure')
      error = commit.statuses.new(stack_id: @stack.id, state: 'error', context: 'ci/error')
      success = commit.statuses.new(stack_id: @stack.id, state: 'success', context: 'ci/success')

      commit.reload.statuses = [pending, failure, success, error]
      assert_equal 'error', commit.status.state

      commit.reload.statuses = [pending, failure, success]
      assert_equal 'failure', commit.status.state

      commit.reload.statuses = [pending, error, success]
      assert_equal 'error', commit.status.state

      commit.reload.statuses = [success, pending]
      assert_equal 'pending', commit.status.state

      commit.reload.statuses = [success]
      assert_equal 'success', commit.status.state

      commit.reload.statuses = []
      assert_equal 'unknown', commit.status.state
    end

    test "merge commits are linked to the matching Pull Request if there is one" do
      commit = @stack.commits.create!(
        author: shipit_users(:shipit),
        authored_at: Time.now,
        committer: shipit_users(:shipit),
        committed_at: Time.now,
        sha: '5590fd8b5f2be05d1fedb763a3605ee461c39074',
        message: "Merge pull request #62 from shipit-engine/yoloshipit\n\nyoloshipit!",
      )
      pull_request = shipit_pull_requests(:shipit_pending)

      assert_predicate commit, :pull_request?
      assert_equal 62, commit.pull_request_number
      assert_equal pull_request.title, commit.pull_request_title
      assert_equal pull_request, commit.pull_request
    end

    test "merge commits infer pull request number and title from the message if it's not a known pull request" do
      commit = @stack.commits.create!(
        author: shipit_users(:shipit),
        authored_at: Time.now,
        committer: shipit_users(:shipit),
        committed_at: Time.now,
        sha: '5590fd8b5f2be05d1fedb763a3605ee461c39074',
        message: "Merge pull request #99 from shipit-engine/yoloshipit\n\nyoloshipit!",
      )

      assert_predicate commit, :pull_request?
      assert_equal 99, commit.pull_request_number
      assert_equal 'yoloshipit!', commit.pull_request_title
      assert_nil commit.pull_request
    end

    test "the merge requester if known overrides the commit author" do
      commit = @stack.commits.create!(
        author: shipit_users(:shipit),
        authored_at: Time.now,
        committer: shipit_users(:shipit),
        committed_at: Time.now,
        sha: '5590fd8b5f2be05d1fedb763a3605ee461c39074',
        message: "Merge pull request #62 from shipit-engine/yoloshipit\n\nyoloshipit!",
      )

      assert_equal shipit_users(:walrus), commit.author
    end

    test "#pull_request_number and #pull_request_title are nil if the message is not a merge commit message" do
      commit = @stack.commits.create!(
        author: shipit_users(:shipit),
        authored_at: Time.now,
        committer: shipit_users(:shipit),
        committed_at: Time.now,
        sha: '5590fd8b5f2be05d1fedb763a3605ee461c39074',
        message: "Yoloshipit!",
      )

      refute_predicate commit, :pull_request?
      assert_nil commit.pull_request_number
      assert_nil commit.pull_request_title
      assert_nil commit.pull_request
    end

    test "#revert? returns false if the message doesn't follow the revert convention" do
      commit = Commit.new(message: "Revert stuff")
      refute_predicate commit, :revert?
    end

    test "#revert? returns true for commits reverted by GitHub" do
      commit = Commit.new(
        message: "Merge pull request #17 from Shopify/revert-16\n\nRevert \"Create README.md\"",
      )
      assert_predicate commit, :revert?
    end

    test "#revert? returns true for commits reverted from CLI" do
      commit = Commit.new(
        message: "Revert \"Super Feature\"\n\nThis reverts commit 49430d5091abc34f2c576c23ebf369ec7094d8aa.",
      )
      assert_predicate commit, :revert?
    end

    test "#revert_of? works with pull requests reverted on GitHub" do
      commit = Commit.new(
        message: "Merge pull request #16 from byroot/casperisfine-patch-1\n\nCreate README.md",
      )
      revert = Commit.new(
        message: "Merge pull request #17 from Shopify/revert-16\n\nRevert \"Create README.md\"",
      )
      assert revert.revert_of?(commit)
    end

    test "#revert_of? works with commits reverted from CLI" do
      commit = Commit.new(
        message: "Create README.md",
      )
      revert = Commit.new(
        message: "Revert \"Create README.md\"\n\nThis reverts commit 49430d5091abc34f2c576c23ebf369ec7094d8aa.",
      )
      assert revert.revert_of?(commit)
    end

    test "#revert_of? works with pull requests reverted from CLI" do
      commit = Commit.new(
        message: "Merge pull request #19 from byroot/casperisfine-patch-1\n\nUpdate README.md",
      )
      revert = Commit.new(
        message: "Revert \"Merge pull request #19 from byroot/casperisfine-patch-1\"\n\nThis reverts commit fa3722ef8372b47160f5d96010d3c54743d192f9, reversing\nchanges made to 868b6f65f759d003c04d056f2f928f18d6813c7e.",
      )
      assert revert.revert_of?(commit)
    end

    private

    def expect_event(stack)
      Pubsubstub.expects(:publish).at_least_once
      Pubsubstub.expects(:publish).with do |channel, _payload, _options = {}|
        channel == "stack.#{stack.id}"
      end
    end

    def expect_hook_emit(commit, event, status_attributes, &block)
      matches = lambda do |payload|
        assert_equal commit, payload[:commit]
        assert_equal commit.stack, payload[:stack]
        assert_equal status_attributes[:state], payload[:status]
      end
      expect_hook(event, commit.stack, matches, &block)
    end
  end
end
