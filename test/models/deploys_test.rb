# frozen_string_literal: true
require 'test_helper'

module Shipit
  class DeploysTest < ActiveSupport::TestCase
    def setup
      @deploy = shipit_deploys(:shipit)
      @deploy.write("dummy output")
      @deploy.pid = 42
      @stack = shipit_stacks(:shipit)
      @user = shipit_users(:walrus)
    end

    test "#rollback? returns false" do
      refute @deploy.rollback?
    end

    test "enqueue" do
      assert_enqueued_with(job: PerformTaskJob, args: [@deploy]) do
        @deploy.enqueue
      end
    end

    test "enqueue when not persisted" do
      assert_raise(RuntimeError) { Deploy.new.enqueue }
    end

    test "run_now! when not persisted" do
      assert_raise(RuntimeError) { Deploy.new.run_now! }
    end

    test "run_now! runs in foreground" do
      PerformTaskJob.any_instance.expects(:perform).once

      @deploy.run_now!
    end

    test "working_directory" do
      assert_equal File.join(@deploy.stack.deploys_path, @deploy.id.to_s), @deploy.working_directory
    end

    test "#since_commit_id returns the database value if present" do
      @deploy.since_commit_id = 1
      assert_equal 1, @deploy.since_commit_id
    end

    test "#since_commit_id returns nil if stack_id isn't set" do
      deploy = Deploy.new
      assert_nil deploy.since_commit_id
    end

    test "#since_commit_id returns a default value if stack_id is set" do
      stack = shipit_stacks(:shipit)
      deploy = stack.deploys.new
      last = stack.deploys.success.last.until_commit_id
      assert_equal last, deploy.since_commit_id
    end

    test "#commits returns empty array if stack isn't set" do
      @deploy.expects(:stack).returns(nil)
      assert_equal [], @deploy.commits
    end

    test "deploys retry up to limit upon timeout when configured" do
      runnable_deploy = shipit_deploys(:shipit_pending)
      deploy_stack = runnable_deploy.stack

      Shipit::Deploy.any_instance.expects(:acquire_git_cache_lock).twice
        .raises(Shipit::Command::TimedOut, 'Deploy timed out')
        .then.raises(Shipit::Command::Error, "Second command error failure")

      perform_enqueued_jobs(only: Shipit::PerformTaskJob) do
        runnable_deploy.enqueue
      end
      assert_performed_jobs 2

      runnable_deploy.reload
      assert_equal 'timedout', runnable_deploy.status

      retried_deploy = deploy_stack.deploys.last
      assert_not_equal runnable_deploy.id, retried_deploy.id
      assert_equal runnable_deploy.since_commit, retried_deploy.since_commit
      assert_equal runnable_deploy.until_commit, retried_deploy.until_commit
      assert_equal 'failed', retried_deploy.status
      assert_equal 1, retried_deploy.retry_attempt
    end

    test "deploys retry up to limit upon failure when configured" do
      runnable_deploy = shipit_deploys(:shipit_pending)
      deploy_stack = runnable_deploy.stack

      Shipit::Deploy.any_instance.expects(:acquire_git_cache_lock).twice
        .raises(Shipit::Command::Error, 'Deploy failed')
        .then.raises(Shipit::Command::Error, "Second deploy failed")

      perform_enqueued_jobs(only: Shipit::PerformTaskJob) do
        runnable_deploy.enqueue
      end
      assert_performed_jobs 2

      runnable_deploy.reload
      assert_equal 'failed', runnable_deploy.status

      retried_deploy = deploy_stack.deploys.last
      assert_not_equal runnable_deploy.id, retried_deploy.id
      assert_equal runnable_deploy.since_commit, retried_deploy.since_commit
      assert_equal runnable_deploy.until_commit, retried_deploy.until_commit
      assert_equal 'failed', retried_deploy.status
      assert_equal 1, retried_deploy.retry_attempt
    end

    test "deploys retry up to limit upon error when configured" do
      runnable_deploy = shipit_deploys(:shipit_pending)
      deploy_stack = runnable_deploy.stack

      Shipit::Deploy.any_instance.expects(:acquire_git_cache_lock).twice
        .raises(StandardError, 'Deploy failed')
        .then.raises(StandardError, "Second deploy failed")

      perform_enqueued_jobs(only: Shipit::PerformTaskJob) do
        runnable_deploy.enqueue
      end
      assert_performed_jobs 2

      runnable_deploy.reload
      assert_equal 'error', runnable_deploy.status

      retried_deploy = deploy_stack.deploys.last
      assert_not_equal runnable_deploy.id, retried_deploy.id
      assert_equal runnable_deploy.since_commit, retried_deploy.since_commit
      assert_equal runnable_deploy.until_commit, retried_deploy.until_commit
      assert_equal 'error', retried_deploy.status
      assert_equal 1, retried_deploy.retry_attempt
    end

    test "deploys do not retry upon timeout when not configured" do
      runnable_deploy = shipit_deploys(:shipit_pending)
      runnable_deploy.update!(retry_attempt: 0, max_retries: 0)

      Shipit::Deploy.any_instance.expects(:acquire_git_cache_lock)
        .raises(Shipit::Command::TimedOut, 'Deploy timed out')

      perform_enqueued_jobs(only: Shipit::PerformTaskJob) do
        runnable_deploy.enqueue
      end
      assert_performed_jobs 1

      runnable_deploy.reload

      assert_equal 'timedout', runnable_deploy.status
    end

    test "rollbacks retry on timeouts if configured" do
      deploy = shipit_deploys(:shipit)
      deploy_stack = deploy.stack

      DeploySpec.any_instance.expects(:retries_on_rollback).returns(1)

      Shipit::Command.any_instance.expects(:run).twice
        .raises(Shipit::Command::TimedOut, 'Rollback timed out')
        .then.raises(Shipit::Command::Error, "Second command error failure")

      first_rollback = nil

      perform_enqueued_jobs(only: Shipit::PerformTaskJob) do
        first_rollback = deploy.trigger_rollback(@user, force: true)
      end
      assert_performed_jobs 2

      first_rollback.reload

      assert_equal 'timedout', first_rollback.status
      retried_rollback = deploy_stack.deploys_and_rollbacks.last

      assert_not_equal first_rollback.id, retried_rollback.id
      assert_equal first_rollback.since_commit, retried_rollback.since_commit
      assert_equal first_rollback.until_commit, retried_rollback.until_commit
      assert_equal 'failed', retried_rollback.status
      assert_equal 1, retried_rollback.max_retries
    end

    test "rollbacks do not retry if not configured" do
      deploy_stack = @deploy.stack

      DeploySpec.any_instance.expects(:retries_on_rollback).returns(0)

      Shipit::Command.any_instance.expects(:run).once
        .raises(Shipit::Command::TimedOut, 'Rollback timed out')
        .then.raises(Shipit::Command::Error, "Second command error failure")

      first_rollback = nil

      perform_enqueued_jobs(only: Shipit::PerformTaskJob) do
        first_rollback = @deploy.trigger_rollback(@user, force: true)
      end
      assert_performed_jobs 1

      first_rollback.reload

      assert_equal 'timedout', first_rollback.status
      assert_equal first_rollback, deploy_stack.deploys_and_rollbacks.last
    end

    test "additions and deletions are denormalized on before create" do
      stack = shipit_stacks(:shipit)
      first = shipit_commits(:first)
      third = shipit_commits(:third)

      deploy = stack.deploys.create!(
        since_commit: first,
        until_commit: third,
      )

      assert_equal 13, deploy.additions
      assert_equal 65, deploy.deletions
    end

    test "#commits returns the commits in the id range" do
      stack = shipit_stacks(:shipit)
      first = shipit_commits(:first)
      last = shipit_commits(:third)

      deploy = stack.deploys.new(
        since_commit: first,
        until_commit: last,
      )

      commits = deploy.commits

      assert_not_empty commits
      assert_equal last.id, commits.map(&:id).max
      assert_not_equal first.id, commits.map(&:id).min
    end

    test "#commits returns commits from newer to older" do
      stack = shipit_stacks(:shipit)
      first = shipit_commits(:first)
      last = shipit_commits(:fourth)

      deploy = stack.deploys.new(
        since_commit: first,
        until_commit: last,
      )

      assert_equal [4, 3, 2], deploy.commits.pluck(:id)
    end

    test "transitioning to an active status does not set ended_at" do
      deploy = shipit_deploys(:shipit_pending)
      deploy.status = 'pending'

      deploy.run!
      deploy.reload

      assert_nil deploy.ended_at
    end

    test "transitioning to success causes an event to be broadcasted" do
      deploy = shipit_deploys(:shipit_pending)

      expect_event(deploy)
      deploy.status = 'running'
      expect_hook(:deploy, deploy.stack, status: 'success', deploy: deploy, stack: deploy.stack) do
        deploy.complete!
      end
    end

    test "transitioning to success persists `ended_at`" do
      deploy = shipit_deploys(:shipit_running)

      assert_nil deploy.ended_at
      deploy.complete!
      deploy.reload
      assert_instance_of ActiveSupport::TimeWithZone, deploy.ended_at
      assert_in_delta Time.now.utc, deploy.ended_at, 2
    end

    test "transitioning to failed causes an event to be broadcasted" do
      deploy = shipit_deploys(:shipit_pending)

      expect_event(deploy)
      deploy.status = 'running'
      expect_hook(:deploy, deploy.stack, status: 'failed', deploy: deploy, stack: deploy.stack) do
        deploy.failure!
      end
    end

    test "transitioning to failed persists `ended_at`" do
      deploy = shipit_deploys(:shipit_running)

      assert_nil deploy.ended_at
      deploy.failure!
      deploy.reload
      assert_instance_of ActiveSupport::TimeWithZone, deploy.ended_at
      assert_in_delta Time.now.utc, deploy.ended_at, 2
    end

    test "transitioning to error causes an event to be broadcasted" do
      deploy = shipit_deploys(:shipit_pending)

      expect_event(deploy)
      deploy.status = 'running'
      expect_hook(:deploy, deploy.stack, status: 'error', deploy: deploy, stack: deploy.stack) do
        deploy.error!
      end
    end

    test "transitioning to error persists `ended_at`" do
      deploy = shipit_deploys(:shipit_running)

      assert_nil deploy.ended_at
      deploy.error!
      deploy.reload
      assert_instance_of ActiveSupport::TimeWithZone, deploy.ended_at
      assert_in_delta Time.now.utc, deploy.ended_at, 2
    end

    test "transitioning to running causes an event to be broadcasted" do
      deploy = shipit_deploys(:shipit_pending)

      expect_event(deploy)
      deploy.status = 'pending'
      expect_hook(:deploy, deploy.stack, status: 'running', deploy: deploy, stack: deploy.stack) do
        deploy.run!
      end
    end

    test "transitioning to running persists `started_at`" do
      deploy = shipit_deploys(:shipit_pending)

      assert_nil deploy.started_at
      deploy.run!
      deploy.reload
      assert_instance_of ActiveSupport::TimeWithZone, deploy.started_at
      assert_in_delta Time.now.utc, deploy.started_at, 2
    end

    test "creating a deploy causes an event to be broadcasted" do
      shipit = shipit_stacks(:shipit)
      deploy = shipit.deploys.build(
        since_commit: shipit.commits.first,
        until_commit: shipit.commits.last,
      )
      deploy.stubs(:merge_request_head_for_commit).returns(nil)

      expect_event(deploy)
      deploy.save!
    end

    test "transitioning to success triggers next deploy when stack uses CD" do
      shipit_commits(:fifth).statuses.create!(stack_id: @stack.id, state: 'success')

      deploy = shipit_deploys(:shipit_running)
      deploy.stack.tasks.where.not(id: deploy.id).update_all(status: 'success')
      deploy.stack.update(continuous_deployment: true)

      assert_difference "Deploy.count" do
        assert_enqueued_with(job: ContinuousDeliveryJob, args: [deploy.stack]) do
          deploy.complete!
        end
        ContinuousDeliveryJob.new.perform(deploy.stack)
      end
    end

    test "transitioning to success skips CD deploy when stack doesn't use it" do
      shipit_commits(:fifth).statuses.create!(stack_id: @stack.id, state: 'success')

      deploy = shipit_deploys(:shipit_running)

      assert_no_difference "Deploy.count" do
        deploy.complete!
      end
    end

    test "transitioning to success skips CD when no successful commits after until_commit" do
      deploy = shipit_deploys(:shipit_running)
      deploy.stack.update(continuous_deployment: true)

      assert_no_difference "Deploy.count" do
        deploy.complete!
      end
    end

    test "transitioning to success schedule an update of the estimated deploy duration" do
      @deploy = shipit_deploys(:shipit_running)
      assert_enqueued_with(job: UpdateEstimatedDeployDurationJob, args: [@deploy.stack]) do
        @deploy.complete!
      end
    end

    test "transitioning to success enqueues a last-deployed git reference update" do
      Shipit.stubs(:update_latest_deployed_ref).returns(true)

      @deploy = shipit_deploys(:shipit_running)
      assert_enqueued_with(job: UpdateGithubLastDeployedRefJob, args: [@deploy.stack]) do
        @deploy.complete!
      end
    end

    test "transitions to any state updates last deploy time to stack record" do
      @deploy = shipit_deploys(:shipit_running)
      @deploy.complete!
      @stack.reload
      assert_in_delta @deploy.ended_at, @stack.last_deployed_at, 2
    end

    test "transitioning to success schedule a MergeMergeRequests job" do
      @deploy = shipit_deploys(:shipit_running)
      assert_enqueued_with(job: ProcessMergeRequestsJob, args: [@deploy.stack]) do
        @deploy.complete!
      end
    end

    test "transitioning to success schedule a fetch of the deployed revision" do
      @deploy = shipit_deploys(:shipit_running)
      assert_enqueued_with(job: FetchDeployedRevisionJob, args: [@deploy.stack]) do
        @deploy.complete!
      end
    end

    test "transitioning to failure schedule a fetch of the deployed revision" do
      @deploy = shipit_deploys(:shipit_running)
      assert_enqueued_with(job: FetchDeployedRevisionJob, args: [@deploy.stack]) do
        @deploy.failure!
      end
    end

    test "transitioning to error schedule a fetch of the deployed revision" do
      @deploy = shipit_deploys(:shipit_running)
      assert_enqueued_with(job: FetchDeployedRevisionJob, args: [@deploy.stack]) do
        @deploy.error!
      end
    end

    test "transitioning to aborted schedule a rollback if required" do
      @deploy = shipit_deploys(:shipit_running)
      @deploy.ping
      @deploy.pid = 42
      @deploy.abort!(rollback_once_aborted: true, aborted_by: @user)

      assert_difference -> { @stack.rollbacks.count }, 1 do
        assert_enqueued_with(job: PerformTaskJob) do
          @deploy.aborted!
        end
      end
    end

    test "transitioning to aborted schedule a rollback to the designated deploy if set" do
      @rollback_to = shipit_deploys(:shipit_pending)
      @deploy = shipit_deploys(:shipit_running)
      @deploy.ping
      @deploy.pid = 42
      @deploy.abort!(rollback_once_aborted: true, rollback_once_aborted_to: @rollback_to, aborted_by: @user)

      assert_difference -> { @stack.rollbacks.count }, 1 do
        assert_enqueued_with(job: PerformTaskJob) do
          @deploy.aborted!
        end
      end
    end

    test "transitioning to aborted locks the stack if a rollback is scheduled" do
      refute @stack.locked?

      @deploy = shipit_deploys(:shipit_running)
      @deploy.ping
      @deploy.pid = 42
      @deploy.abort!(rollback_once_aborted: true, aborted_by: @user)
      @deploy.aborted!

      assert_predicate @stack.reload, :locked?
      assert_equal @user, @stack.lock_author
    end

    test "transitioning to aborted emits a lock hook if a rollback is scheduled" do
      refute_predicate @stack, :locked?

      @deploy = shipit_deploys(:shipit_running)
      @deploy.ping
      @deploy.pid = 42
      @deploy.abort!(rollback_once_aborted: true, aborted_by: @user)

      expect_hook(:lock, @stack, locked: true, lock_details: nil, stack: @stack) do
        @deploy.aborted!
      end
    end

    test "#build_rollback returns an unsaved record" do
      assert @deploy.build_rollback.new_record?
    end

    test "#build_rollback returns a rollback" do
      assert @deploy.build_rollback.rollback?
    end

    test "#build_rollback set the id of the rollbacked deploy" do
      rollback = @deploy.build_rollback
      assert_equal @deploy.id, rollback.parent_id
    end

    test "#build_rollback set the last_deployed_commit as the rollback since_commit" do
      rollback = @deploy.build_rollback
      assert_equal @stack.last_deployed_commit, rollback.since_commit
    end

    test "#trigger_rollback rolls the stack back to this deploy" do
      assert_equal shipit_commits(:fourth), @stack.last_deployed_commit
      rollback = @deploy.trigger_rollback
      rollback.run!
      rollback.complete!
      assert_equal shipit_commits(:second), @stack.last_deployed_commit
    end

    def create_test_stack(repository: Shipit::Repository.find_or_create_by!(owner: "shopify-test", name: "shipit-engine-test"))
      Shipit::Stack.create(
        repository: repository,
        environment: 'production',
        branch: "master",
        merge_queue_enabled: true,
        created_at: "2019-01-01 00:00:00",
        updated_at: "2019-01-02 10:10:10",
      )
    end

    def create_test_commit(stack_id:, user_id:)
      Shipit::Commit.new(
        stack_id: stack_id,
        author_id: user_id,
        sha: SecureRandom.hex(20),
        additions: 2,
        deletions: 0,
        committer_id: user_id,
        message: "Some commit message.",
        authored_at: "2019-01-02 10:11:10",
        committed_at: "2019-01-02 10:11:10",
      )
    end

    def create_test_status(commit_id:, stack_id:, state: "success")
      Shipit::Status.new(
        description: "Description for commit #{commit_id}",
        stack_id: stack_id,
        commit_id: commit_id,
        state: state,
      )
    end

    def create_test_deploy(stack_id:, user_id:, since_commit_id:, until_commit_id: since_commit_id)
      Shipit::Deploy.new(
        stack_id: stack_id,
        user_id: user_id,
        since_commit_id: since_commit_id,
        until_commit_id: until_commit_id,
        status: "success",
        type: "Shipit::Deploy",
      )
    end

    # For test purposes, we want to fail fast if a series of records are given sequential ids.
    # Check that the next item in the series is 1 greater than the last.
    def assert_generated_record_ids_are_sequential(record_id_series)
      record_id_series[0..-2].each_with_index do |id_element, index|
        assert_equal(id_element + 1, record_id_series[index + 1])
      end
    end

    def generate_commits(amount:, stack_id:, user_id:, validate:)
      commit_ids = []
      amount.times do
        commit = create_test_commit(stack_id: stack_id, user_id: user_id)
        commit.save
        commit.reload
        commit_ids << commit.id
      end

      if validate then assert_generated_record_ids_are_sequential(commit_ids) end
      commit_ids
    end

    test "#trigger_revert rolls the stack back to before this deploy" do
      user_id = @user.id
      test_stack = create_test_stack
      test_stack.save
      test_stack.reload
      stack_id = test_stack.id

      # Create valid commit history for the stack. We need several commits to deploy and roll back through.
      commit_ids = generate_commits(amount: 4, stack_id: stack_id, user_id: user_id, validate: true)
      commit_ids.each { |commit_id| create_test_status(commit_id: commit_id, stack_id: stack_id, state: "success").save }

      # Three deploys of commits 1-2, 2-3 and 3-4 respectively. Reverting last should result in Deploy 3 (commit 3) being latest.
      3.times { |index| create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[index], until_commit_id: commit_ids[index + 1]).save }

      # Get the reference with Rails-mutated field values.
      commit3 = Shipit::Commit.second_to_last
      commit4 = Shipit::Commit.last
      deploy3 = Shipit::Deploy.last

      assert_equal commit4, test_stack.last_deployed_commit

      deploy_to_revert = test_stack.deploys.last

      assert_equal deploy3, deploy_to_revert

      rollback = deploy_to_revert.trigger_revert
      rollback.run!
      rollback.complete!

      last_deploy = test_stack.last_completed_deploy

      assert_equal commit3, test_stack.last_deployed_commit
      assert_equal commit3, last_deploy.until_commit
      assert_equal "Shipit::Rollback", last_deploy.type
    end

    test "#trigger_revert uses rollback_to if set" do
      test_stack = create_test_stack
      test_stack.save
      test_stack.reload

      running_deploy = shipit_deploys(:shipit_running)
      rollback_to = shipit_deploys(:shipit_pending)

      final_rollback = running_deploy.trigger_revert(rollback_to: rollback_to)

      assert_equal "Shipit::Rollback", final_rollback.type
      assert_equal 4, final_rollback.until_commit_id
    end

    test "#trigger_revert skips unsuccessful deploys when reverting" do
      user_id = @user.id
      test_stack = create_test_stack
      test_stack.save
      test_stack.reload
      stack_id = test_stack.id

      # Create valid commit history for the stack. We need several commits to deploy and roll back through.
      commit_ids = generate_commits(amount: 4, stack_id: stack_id, user_id: user_id, validate: true)
      commit_ids.each { |commit_id| create_test_status(commit_id: commit_id, stack_id: stack_id, state: "success").save }

      # We want the following order of Deploys:
      # 1. Success (commits 1-2)
      # 2. Faulty (commits 2-3)
      # 3. Rollback to Success (-> commits 1-2)
      # 4. Running (commits 3-4)
      # 5. Reversion of the running deploy to the last successful deploy. (-> commits 1-2, i.e. the successful deploy.)

      deploy1 = create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[0], until_commit_id: commit_ids[1])
      deploy1.save

      deploy2 = create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[1], until_commit_id: commit_ids[2])
      deploy2.status = "faulty"
      deploy2.save

      rollback = test_stack.deploys.second_to_last.trigger_rollback(@user)
      rollback.run!
      rollback.complete!

      assert_equal commit_ids[1], test_stack.last_deployed_commit.id

      deploy3 = create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[2], until_commit_id: commit_ids[3])
      deploy3.status = "running"
      deploy3.rollback_once_aborted = false
      deploy3.save

      running_deploy = deploy3.reload
      running_deploy.abort!(aborted_by: @user)
      running_deploy.reload

      assert_equal "error", running_deploy.status

      final_rollback = running_deploy.trigger_revert
      final_rollback.run!
      final_rollback.complete!

      last_deploy = test_stack.last_completed_deploy

      # The rollback deploy should be from the last commit until the second commit.
      assert_equal "success", last_deploy.status
      assert_equal "Shipit::Rollback", last_deploy.type
      assert_equal commit_ids[-1], last_deploy.since_commit_id
      assert_equal commit_ids[1], last_deploy.until_commit_id
      assert_equal commit_ids[1], test_stack.last_deployed_commit.id
    end

    test "#trigger_revert skips non-deploy tasks when rolling back" do
      # The revert functionality should only consider Shipit::Deploy and Shipit::Rollback when selecting a target to roll back to for the user.
      # But it is possible for other task types to be defined, so we want to ensure that they are properly skipped, as we can't know whether they are 'valid' to roll back to.
      user_id = @user.id
      test_stack = create_test_stack
      test_stack.save
      test_stack.reload
      stack_id = test_stack.id

      # Create valid commit history for the stack. We need several commits to deploy and roll back through.
      commit_ids = generate_commits(amount: 4, stack_id: stack_id, user_id: user_id, validate: true)
      commit_ids.each { |commit_id| create_test_status(commit_id: commit_id, stack_id: stack_id, state: "success").save }

      # We want the following order of Deploys:
      # 1. Success (commits 1-2)
      # 2. Success, but type is not of deploy (commits 2-3)
      # 3. Running (commits 3-4)
      # 4. Reversion of the running deploy to the last successful deploy. (-> commits 1-2, i.e. the successful deploy.)
      # If the revert functionality doesn't restrict to deploys and rollbacks, then commit 3 will be latest deployed when the reversion is done.

      deploy1 = create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[0], until_commit_id: commit_ids[1])
      deploy1.save

      deploy2 = create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[1], until_commit_id: commit_ids[2])
      deploy2.type = "Shipit::Fake"
      deploy2.save

      deploy3 = create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[2], until_commit_id: commit_ids[3])
      deploy3.status = "running"
      deploy3.rollback_once_aborted = false
      deploy3.save

      running_deploy = deploy3.reload
      running_deploy.abort!(aborted_by: @user)
      running_deploy.reload

      rollback = running_deploy.trigger_revert
      rollback.run!
      rollback.complete!

      last_deploy = test_stack.last_completed_deploy
      assert_equal "success", last_deploy.status
      assert_equal "Shipit::Rollback", last_deploy.type
      assert_equal commit_ids[-1], last_deploy.since_commit_id
      assert_equal commit_ids[1], last_deploy.until_commit_id
      assert_equal commit_ids[1], test_stack.last_deployed_commit.id
    end

    test "#trigger_revert skips deploys from other stacks" do
      # The revert functionality should only consider Shipit::Deploy and Shipit::Rollback's from the same stack when selecting a target to roll back to for the user.
      # But deploys and commits from other stacks can have ids between the current and the previous of this stack, so we want a test to ensure that the deploy
      # from the correct stack is selected.
      user_id = @user.id
      test_stack = create_test_stack
      test_stack.save
      other_stack = create_test_stack(repository: Shipit::Repository.create!(owner: "_", name: "_some-other-repository"))
      other_stack.save
      other_stack.reload
      stack_id = test_stack.id

      # Create valid commit history for the stack. We need several commits to deploy and roll back through.
      commit_ids = generate_commits(amount: 4, stack_id: stack_id, user_id: user_id, validate: true)
      commit_ids.each { |commit_id| create_test_status(commit_id: commit_id, stack_id: stack_id, state: "success").save }

      # We want the following order of Deploys:
      # 1. Success (commits 1-2)
      # 2. Success, but belongs to a different stack (commits 2-3)
      # 3. Running (commits 3-4)
      # 4. Reversion of the running deploy to the last successful deploy of the same stack. (-> commits 1-2, i.e. the successful deploy.)
      # If the revert functionality doesn't restrict to the correct stack, then commit 3 will be latest deployed when the reversion is done.

      deploy1 = create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[0], until_commit_id: commit_ids[1])
      deploy1.save

      deploy2 = create_test_deploy(stack_id: other_stack.id, user_id: user_id, since_commit_id: commit_ids[1], until_commit_id: commit_ids[2])
      deploy2.save

      deploy3 = create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[2], until_commit_id: commit_ids[3])
      deploy3.status = "running"
      deploy3.rollback_once_aborted = false
      deploy3.save

      running_deploy = deploy3.reload
      running_deploy.abort!(aborted_by: @user)
      running_deploy.reload

      rollback = running_deploy.trigger_revert
      rollback.run!
      rollback.complete!

      last_deploy = test_stack.last_completed_deploy
      assert_equal "success", last_deploy.status
      assert_equal "Shipit::Rollback", last_deploy.type
      assert_equal commit_ids[-1], last_deploy.since_commit_id
      assert_equal commit_ids[1], last_deploy.until_commit_id
      assert_equal commit_ids[1], test_stack.last_deployed_commit.id
    end

    test "#trigger_revert no prior deploy to roll back to" do
      user_id = @user.id
      test_stack = create_test_stack
      test_stack.save
      test_stack.reload
      stack_id = test_stack.id

      commit_ids = generate_commits(amount: 2, stack_id: stack_id, user_id: user_id, validate: true)
      commit_ids.each { |commit_id| create_test_status(commit_id: commit_id, stack_id: stack_id, state: "success").save }
      deploy1 = create_test_deploy(stack_id: stack_id, user_id: user_id, since_commit_id: commit_ids[0], until_commit_id: commit_ids[1])
      deploy1.save

      rollback = deploy1.trigger_revert
      rollback.run!
      rollback.complete!

      assert_equal deploy1.until_commit_id, rollback.since_commit_id
      assert_equal deploy1.since_commit_id, rollback.until_commit_id

      last_deploy = test_stack.last_completed_deploy
      assert_equal "success", last_deploy.status
      assert_equal "Shipit::Rollback", last_deploy.type
      assert_equal deploy1.until_commit_id, last_deploy.since_commit_id
      assert_equal deploy1.since_commit_id, last_deploy.until_commit_id
      assert_equal deploy1.since_commit_id, test_stack.last_deployed_commit.id
    end

    test "#trigger_rollback creates a new Rollback" do
      assert_difference -> { Rollback.count }, 1 do
        @deploy.trigger_rollback(@user)
      end
    end

    test "#trigger_rollback schedule the task" do
      Hook.expects(:emit).at_least_once
      assert_enqueued_with(job: PerformTaskJob) do
        @deploy.trigger_rollback(@user)
      end
    end

    test "#trigger_rollback locks the stack" do
      refute @stack.locked?
      @deploy.trigger_rollback(@user)
      assert @stack.reload.locked?
      assert_equal @user, @stack.lock_author
    end

    test "#trigger_rollback does not lock the stack if not requested" do
      refute @stack.locked?
      @deploy.trigger_rollback(@user, lock: false)
      refute @stack.reload.locked?
    end

    test "#trigger_rollback marks the rollback as `ignored_safeties` if the force option was used" do
      rollback = @deploy.trigger_rollback(@user, force: true)
      assert_predicate rollback, :ignored_safeties?
    end

    test "abort! transition to `aborting`" do
      @deploy.ping
      @deploy.abort!(aborted_by: @user)
      assert_equal 'aborting', @deploy.status
    end

    test "abort! schedule the rollback if `rollback_once_aborted` is true" do
      @deploy.abort!(rollback_once_aborted: true, aborted_by: @user)
      assert_predicate @deploy.reload, :rollback_once_aborted?
    end

    test "abort! record the abort order if the task is alive" do
      @deploy.ping
      aborts = []

      @deploy.abort!(aborted_by: @user)
      @deploy.should_abort? { |abort_count| aborts << abort_count }
      assert_equal [1], aborts

      3.times { @deploy.abort!(aborted_by: @user) }
      @deploy.should_abort? { |abort_count| aborts << abort_count }
      assert_equal [1, 2, 3, 4], aborts
    end

    test "abort! mark the deploy as error if it isn't alive and isn't finished" do
      @deploy = shipit_deploys(:shipit_running)
      refute_predicate @deploy, :alive?
      refute_predicate @deploy, :finished?

      @deploy.abort!(aborted_by: @user)
      assert_predicate @deploy, :error?
    end

    test "#chunk_output fetches from Redis if logs not rolled up" do
      assert_equal Shipit.redis.get(@deploy.send(:output_key)), @deploy.chunk_output
      refute @deploy.rolled_up
    end

    test "#chunk_output returns logs from records if rolled up" do
      expected_output = Shipit.redis.get(@deploy.send(:output_key))
      @deploy.rollup_chunks

      assert_no_queries do
        assert_equal expected_output, @deploy.chunk_output
        assert @deploy.rolled_up
      end
    end

    test "#accept! bails out if the deploy is successful already" do
      assert_predicate @deploy, :success?

      Deploy::CONFIRMATIONS_REQUIRED.times do
        @deploy.accept!
        assert_predicate @deploy, :success?
      end
    end

    test "#accept! first transition to flapping then ultimately to success if the deploy was failed" do
      @deploy = shipit_deploys(:shipit2)
      assert_predicate @deploy, :failed?

      (Deploy::CONFIRMATIONS_REQUIRED - 1).times do
        @deploy.accept!
        assert_predicate @deploy, :flapping?
      end

      @deploy.accept!
      assert_predicate @deploy, :success?
    end

    test "#reject! bails out if the deploy is failed already" do
      @deploy = shipit_deploys(:shipit2)
      assert_predicate @deploy, :failed?

      Deploy::CONFIRMATIONS_REQUIRED.times do
        @deploy.reject!
        assert_predicate @deploy, :failed?
      end
    end

    test "#reject! bails out if the deploy is canceled already" do
      @deploy = shipit_deploys(:shipit_aborted)
      assert_predicate @deploy, :aborted?

      Deploy::CONFIRMATIONS_REQUIRED.times do
        @deploy.reject!
        assert_predicate @deploy, :aborted?
      end
    end

    test "#reject! first transition to flapping then ultimately to failed if the deploy was successful" do
      assert_predicate @deploy, :success?

      (Deploy::CONFIRMATIONS_REQUIRED - 1).times do
        @deploy.reject!
        assert_predicate @deploy, :flapping?
      end

      @deploy.reject!
      assert_predicate @deploy, :failed?
    end

    test "entering flapping state triggers webhooks" do
      assert_enqueued_with job: EmitEventJob do
        @deploy.reject!
      end
      assert_predicate @deploy, :flapping?
    end

    test "#ping updates the task status key" do
      refute_predicate @deploy, :alive?
      @deploy.ping
      assert_predicate @deploy, :alive?
    end

    test "triggering a deploy sets the release status as pending" do
      @commit = shipit_commits(:canaries_fifth)
      @stack = @commit.stack

      assert_difference -> { ReleaseStatus.count }, +1 do
        assert_equal 'unknown', @commit.last_release_status.state
        @deploy = @stack.trigger_deploy(@commit, AnonymousUser.new, force: true)
        assert_equal 'pending', @commit.last_release_status.state
      end
    end

    test "failing a deploy sets the release status as error" do
      @deploy = shipit_deploys(:canaries_running)
      assert_difference -> { ReleaseStatus.count }, +1 do
        assert_not_equal 'error', @deploy.last_release_status.state
        @deploy.report_failure!(StandardError.new)
        assert_equal 'error', @deploy.last_release_status.state
      end
    end

    test "succeeding a deploy sets the release status as success if the status delay is 0s" do
      @deploy = shipit_deploys(:canaries_running)
      @deploy.stack.expects(:release_status_delay).at_least_once.returns(Duration.parse(0))

      assert_difference -> { ReleaseStatus.count }, +1 do
        assert_not_equal 'success', @deploy.last_release_status.state
        @deploy.complete!
        assert_equal 'success', @deploy.last_release_status.state
      end
    end

    test "succeeding a deploy sets the release status as pending if the status delay is longer than 0s" do
      @deploy = shipit_deploys(:canaries_running)
      @deploy.stack.expects(:release_status_delay).at_least_once.returns(Duration.parse(1))

      assert_difference -> { ReleaseStatus.count }, +1 do
        assert_not_equal 'success', @deploy.last_release_status.state
        assert_enqueued_with(job: MarkDeployHealthyJob) do
          @deploy.report_complete!
          assert_equal 'validating', @deploy.status
        end
        assert_equal 'pending', @deploy.last_release_status.state
      end
    end

    test "succeeding a deploy sets the release status as pending and does not schedule job if the status delay is negative (-1)" do
      @deploy = shipit_deploys(:canaries_running)
      @deploy.stack.expects(:release_status_delay).at_least_once.returns(Duration.parse(-1))

      assert_difference -> { ReleaseStatus.count }, +1 do
        assert_not_equal 'success', @deploy.last_release_status.state
        @deploy.report_complete!
        assert_equal 'validating', @deploy.status
        assert_equal 'pending', @deploy.last_release_status.state
      end
    end

    test "triggering a rollback via abort! sets the release status as failure" do
      @deploy = shipit_deploys(:canaries_running)
      @deploy.ping

      assert_difference -> { ReleaseStatus.count }, +2 do
        assert_equal 'running', @deploy.status
        assert_not_equal 'failure', @deploy.last_release_status.state

        @deploy.abort!(rollback_once_aborted: true, aborted_by: shipit_users(:walrus))

        @deploy.reload
        assert_equal 'aborting', @deploy.status
        assert_equal 'failure', @deploy.last_release_status.state

        @deploy.aborted!

        @deploy.reload
        assert_equal 'aborted', @deploy.status
        assert_equal 'failure', @deploy.last_release_status.state
      end
    end

    test "manually triggered rollbacks sets the release status as failure" do
      @deploy = shipit_deploys(:canaries_validating)
      @middle_deploy = shipit_deploys(:canaries_faulty)
      @rollback_to_deploy = shipit_deploys(:canaries_success)

      assert_difference -> { ReleaseStatus.count }, +2 do
        assert_equal 'validating', @deploy.status
        assert_equal 'pending', @deploy.last_release_status.state

        @rollback_to_deploy.trigger_rollback(force: true)
        @rollback_to_deploy.reload
        @deploy.reload

        assert_equal 'faulty', @deploy.status
        assert_equal 'failure', @deploy.last_release_status.state

        assert_equal 'faulty', @middle_deploy.status
        assert_equal 'failure', @middle_deploy.last_release_status.state

        assert_equal 'success', @rollback_to_deploy.status
      end
    end

    test "manually triggered rollbacks sets rollbacked deploys as faulty and not the rollback task" do
      @deploy = shipit_deploys(:canaries_validating)
      @middle_deploy = shipit_deploys(:canaries_faulty)
      @rollback_to_deploy = shipit_deploys(:canaries_success)

      @rollback_task = @rollback_to_deploy.trigger_rollback(force: true)

      @rollback_task.run!
      @rollback_task.complete!
      @rollback_task.reload
      @deploy.reload
      @middle_deploy.reload

      assert_equal 'faulty', @deploy.status
      assert_equal 'failure', @deploy.last_release_status.state

      assert_equal 'faulty', @middle_deploy.status
      assert_equal 'failure', @middle_deploy.last_release_status.state

      assert_equal 'success', @rollback_task.status
    end

    test "succeeding a deploy creates CommitDeploymentStatuses" do
      @deploy = shipit_deploys(:shipit_running)
      refute_empty @deploy.commit_deployments

      assert_difference -> { CommitDeploymentStatus.count }, @deploy.commit_deployments.size do
        @deploy.report_complete!
      end

      assert_equal 'success', CommitDeploymentStatus.last.status
    end

    test "creates one CommitDeployment and status per commit, and one more for the batch head" do
      template_task = shipit_tasks(:shipit_pending)
      deploy = template_task.stack.deploys.build(
        since_commit: template_task.since_commit,
        until_commit: template_task.until_commit,
      )

      expected_delta = deploy.commits.select(&:pull_request?).size + 1
      assert_difference -> { CommitDeployment.count }, expected_delta do
        assert_difference -> { CommitDeploymentStatus.count }, expected_delta do
          deploy.save!
        end
      end

      refute_nil CommitDeployment.find_by(sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e')
      refute_nil CommitDeployment.find_by(sha: deploy.until_commit.sha)
    end

    private

    def expect_event(deploy)
      Pubsubstub.expects(:publish).at_least_once
      Pubsubstub.expects(:publish).with do |channel, _payload, _options|
        channel == "stack.#{deploy.stack.id}"
      end
    end
  end
end
