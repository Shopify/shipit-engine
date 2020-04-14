require 'test_helper'
require 'securerandom'

module Shipit
  class StacksTest < ActiveSupport::TestCase
    def setup
      @stack = shipit_stacks(:shipit)
      @expected_base_path = Rails.root.join('data', 'stacks', @stack.to_param).to_s
      GithubHook.any_instance.stubs(:teardown!)
    end

    test "branch defaults to master" do
      @stack.branch = ""
      assert @stack.save
      assert_equal 'master', @stack.branch
    end

    test "environment defaults to production" do
      @stack.environment = ""
      assert @stack.save
      assert_equal 'production', @stack.environment
    end

    test "environment can contain a `:`" do
      @stack.environment = 'foo:bar'
      assert @stack.save
      assert_equal 'foo:bar', @stack.environment
    end

    test "repo_http_url" do
      assert_equal "https://github.com/#{@stack.repo_owner}/#{@stack.repo_name}", @stack.repo_http_url
    end

    test "repo_git_url" do
      assert_equal "https://github.com/#{@stack.repo_owner}/#{@stack.repo_name}.git", @stack.repo_git_url
    end

    test "base_path" do
      assert_equal @expected_base_path, @stack.base_path.to_s
    end

    test "deploys_path" do
      assert_equal File.join(@expected_base_path, "deploys"), @stack.deploys_path.to_s
    end

    test "git_path" do
      assert_equal File.join(@expected_base_path, "git"), @stack.git_path.to_s
    end

    test "#trigger_deploy persist a new deploy" do
      last_commit = shipit_commits(:third)
      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
      assert deploy.persisted?
      assert_equal last_commit.id, deploy.until_commit_id
      assert_equal shipit_deploys(:shipit_complete).until_commit_id, deploy.since_commit_id
    end

    test "#trigger_deploy emits a hook" do
      original_receivers = Shipit.internal_hook_receivers

      FakeReceiver = Module.new do
        mattr_accessor :hooks
        self.hooks = []

        def self.deliver(event, stack, payload)
          hooks << [event, stack, payload]
        end
      end
      Shipit.internal_hook_receivers = [FakeReceiver]

      last_commit = shipit_commits(:third)
      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
      assert_includes FakeReceiver.hooks, [
        :deploy,
        @stack,
        {deploy: deploy, status: "pending", stack: @stack},
      ]
    ensure
      Shipit.internal_hook_receivers = original_receivers
    end

    test "#trigger_deploy deploy until the commit passed in argument" do
      last_commit = shipit_commits(:third)
      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
      assert_equal last_commit.id, deploy.until_commit_id
    end

    test "#trigger_deploy since_commit is the last completed deploy until_commit if there is a previous deploy" do
      last_commit = shipit_commits(:fifth)
      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
      assert_equal shipit_deploys(:shipit_complete).until_commit_id, deploy.since_commit_id
    end

    test "#trigger_deploy since_commit is the first stack commit if there is no previous deploy" do
      @stack.deploys.destroy_all

      last_commit = shipit_commits(:third)
      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
      assert_equal @stack.commits.first.id, deploy.since_commit_id
    end

    test "#trigger_deploy enqueues a deploy job" do
      @stack.deploys.destroy_all
      Deploy.any_instance.expects(:enqueue).once

      last_commit = shipit_commits(:third)
      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
      assert_instance_of Deploy, deploy
    end

    test "#trigger_deploy doesn't enqueues a deploy job when run_now is provided" do
      @stack.deploys.destroy_all
      Deploy.any_instance.expects(:run_now!).once

      last_commit = shipit_commits(:third)
      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new, run_now: true)
      assert_instance_of Deploy, deploy
    end

    test "#trigger_deploy marks the deploy as `ignored_safeties` if the commit wasn't deployable" do
      last_commit = shipit_commits(:fifth)
      refute_predicate last_commit, :deployable?

      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
      assert_predicate deploy, :ignored_safeties?
    end

    test "#trigger_deploy doesn't mark the deploy as `ignored_safeties` if the commit was deployable" do
      last_commit = shipit_commits(:third)
      assert_predicate last_commit, :deployable?

      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
      refute_predicate deploy, :ignored_safeties?
    end

    test "#update_deployed_revision bail out if there is an active deploy" do
      @stack.deploys_and_rollbacks.last.update_columns(status: 'running')
      assert_no_difference 'Deploy.count' do
        @stack.update_deployed_revision(shipit_commits(:fifth).sha)
      end
    end

    test "#update_deployed_revision bail out if sha is unknown" do
      assert_no_difference 'Deploy.count' do
        @stack.update_deployed_revision('skldjaslkdjas')
      end
    end

    test "#update_deployed_revision create a new completed deploy" do
      assert_equal shipit_commits(:fourth), @stack.last_deployed_commit
      assert_difference 'Deploy.count', 1 do
        deploy = @stack.update_deployed_revision(shipit_commits(:fifth).sha)
        assert_not_nil deploy
        assert_equal shipit_commits(:fourth), deploy.since_commit
        assert_equal shipit_commits(:fifth), deploy.until_commit
      end
      assert_equal shipit_commits(:fifth), @stack.last_deployed_commit
    end

    test "#update_deployed_revision creates a new completed deploy without previous deploys" do
      stack = shipit_stacks(:undeployed_stack)
      assert_empty stack.deploys_and_rollbacks
      assert_difference 'Deploy.count', 1 do
        deploy = stack.update_deployed_revision(shipit_commits(:undeployed_stack_first).sha)
        assert_not_nil deploy
        assert_equal shipit_commits(:undeployed_stack_first), deploy.since_commit
        assert_equal shipit_commits(:undeployed_stack_first), deploy.until_commit
      end
      assert_equal shipit_commits(:undeployed_stack_first), stack.last_deployed_commit
    end

    test "#update_deployed_revision works with short shas" do
      Deploy.active.update_all(status: 'error')

      assert_equal shipit_commits(:fourth), @stack.last_deployed_commit
      assert_difference 'Deploy.count', 1 do
        deploy = @stack.update_deployed_revision(shipit_commits(:fifth).sha[0..5])
        assert_not_nil deploy
        assert_equal shipit_commits(:fourth), deploy.since_commit
        assert_equal shipit_commits(:fifth), deploy.until_commit
      end
      assert_equal shipit_commits(:fifth), @stack.last_deployed_commit
    end

    test "#update_deployed_revision accepts the deploy if the reported revision is consistent" do
      Deploy.active.update_all(status: 'error')

      Deploy.any_instance.expects(:accept!).once
      last_deploy = @stack.deploys_and_rollbacks.completed.last
      @stack.update_deployed_revision(last_deploy.until_commit.sha)
    end

    test "#update_deployed_revision reject the deploy if the reported revision is inconsistent" do
      Deploy.active.update_all(status: 'error')

      Deploy.any_instance.expects(:reject!).once
      last_deploy = @stack.deploys_and_rollbacks.completed.last
      @stack.update_deployed_revision(last_deploy.since_commit.sha)
    end

    test "#create queues a GithubSyncJob" do
      assert_enqueued_with(job: GithubSyncJob) do
        Stack.create!(repository: shipit_repositories(:rails))
      end
    end

    test "#destroy also destroy associated GithubHooks" do
      assert_difference -> { GithubHook.count }, -2 do
        shipit_stacks(:shipit).destroy
      end
    end

    test "#destroy also destroy associated Commits" do
      assert_difference -> { Commit.count }, -shipit_stacks(:shipit).commits.count do
        shipit_stacks(:shipit).destroy
      end
    end

    test "#destroy also destroy associated CommitDeployments" do
      assert_difference -> { CommitDeployment.count }, -8 do
        shipit_stacks(:shipit).destroy
      end
    end

    test "#destroy delete all local files (git mirror and deploy clones)" do
      FileUtils.expects(:rm_rf).with(Rails.root.join('data', 'stacks', 'shopify', 'shipit-engine', 'production').to_s)
      shipit_stacks(:shipit).destroy
    end

    test "#active_task? is false if stack has no deploy in either pending or running state" do
      @stack.deploys.active.destroy_all
      refute @stack.active_task?
    end

    test "#active_task? is false if stack has no deploy at all" do
      @stack.deploys.destroy_all
      refute @stack.active_task?
    end

    test "#active_task? is true if stack has a deploy in either pending or running state" do
      @stack.trigger_deploy(shipit_commits(:third), AnonymousUser.new)
      assert @stack.active_task?
    end

    test "#active_task? is true if a rollback is ongoing" do
      shipit_deploys(:shipit_complete).trigger_rollback(AnonymousUser.new)
      assert @stack.active_task?
    end

    test ".run_deploy_in_foreground triggers a deploy" do
      stack = Stack.create!(
        repository: Repository.new(owner: "foo", name: "bar"),
        environment: 'production',
      )
      commit = shipit_commits(:first)
      stack.commits << commit

      Stack.any_instance.expects(:trigger_deploy).with(anything, anything, env: {}, force: true, run_now: true)

      Stack.run_deploy_in_foreground(stack: stack.to_param, revision: commit.sha)
    end

    test ".review_request is nil by default" do
      assert_nil @stack.review_request
    end

    test ".review_request returns nil when all pull requests are merge requests" do
      @stack = shipit_stacks(:shipit)

      assert_nil @stack.review_request
    end

    test ".review_request returns latest non merge request" do
      @stack = shipit_stacks(:shipit)
      @pull_request = PullRequest.create!(stack: @stack, number: "1", review_request: true)

      assert @stack.review_request, @pull_request
    end

    test "#active_task? is memoized" do
      assert_queries(1) do
        10.times { @stack.active_task? }
      end
    end

    test "#deployable? returns true if the stack is not locked and is not deploying" do
      @stack.deploys.destroy_all
      assert_predicate @stack, :deployable?
    end

    test "#deployable? returns false if the stack is locked" do
      @stack.update!(lock_reason: 'Maintenance operation')
      refute_predicate @stack, :deployable?
    end

    test "#deployable? returns false if the stack is deploying" do
      @stack.trigger_deploy(shipit_commits(:third), AnonymousUser.new)
      refute_predicate @stack, :deployable?
    end

    test "#allows_merges? returns true if the stack is not locked and the branch is green" do
      assert_predicate @stack, :allows_merges?
    end

    test "#allows_merges? returns false if the stack is locked" do
      @stack.update!(lock_reason: 'Maintenance operation')
      refute_predicate @stack, :allows_merges?
    end

    test "#allows_merges? returns false if the merge queue is disabled" do
      @stack.update!(merge_queue_enabled: false)
      refute_predicate @stack, :allows_merges?
    end

    test "#allows_merges? returns false if the branch is failing" do
      @stack.undeployed_commits.last.statuses.create!(context: 'ci/travis', state: 'failure', stack: @stack)
      refute_predicate @stack, :allows_merges?
    end

    test "#monitoring is empty if cached_deploy_spec is blank" do
      @stack.cached_deploy_spec = nil
      assert_equal [], @stack.monitoring
    end

    test "#monitoring returns deploy_spec's content" do
      assert_equal [{'image' => 'https://example.com/monitor.png', 'width' => 200, 'height' => 300}], @stack.monitoring
    end

    test "#destroy deletes the related commits" do
      assert_difference -> { @stack.commits.count }, -@stack.commits.count do
        @stack.destroy
      end
    end

    test "#destroy deletes the related tasks" do
      assert_difference -> { @stack.tasks.count }, -@stack.tasks.count do
        @stack.destroy
      end
    end

    test "#destroy deletes the related webhooks" do
      assert_difference -> { @stack.github_hooks.count }, -@stack.github_hooks.count do
        @stack.destroy
      end
    end

    test "locking the stack triggers a webhook" do
      expect_hook(:lock, @stack, locked: true, lock_details: nil, stack: @stack) do
        @stack.update(lock_reason: "Just for fun", lock_author: shipit_users(:walrus))
      end
    end

    test "unlocking the stack triggers a webhook" do
      freeze_time do
        time = Time.current
        @stack.update(lock_reason: "Just for fun", lock_author: shipit_users(:walrus))
        travel 1.day
        expect_hook(:lock, @stack, locked: false, lock_details: {from: time, until: Time.current}, stack: @stack) do
          @stack.update(lock_reason: nil)
        end
      end
    end

    test "unlocking the stack triggers a MergePullRequests job" do
      assert_no_enqueued_jobs(only: MergePullRequestsJob) do
        @stack.update(lock_reason: "Just for fun", lock_author: shipit_users(:walrus))
      end

      assert_enqueued_with(job: MergePullRequestsJob, args: [@stack]) do
        @stack.update(lock_reason: nil)
      end
    end

    test "the git cache lock prevent concurrent access to the git cache" do
      @stack.acquire_git_cache_lock do
        assert_raises Flock::TimeoutError do
          @stack.acquire_git_cache_lock(timeout: 0.1) {}
        end
      end
    end

    test "the git cache lock is scoped to the stack" do
      called = false
      shipit_stacks(:cyclimse).acquire_git_cache_lock do
        @stack.acquire_git_cache_lock do
          called = true
        end
      end
      assert called
    end

    test "#clear_git_cache! deletes the stack git directory" do
      FileUtils.mkdir_p(@stack.git_path)
      path = File.join(@stack.git_path, 'foo')
      File.write(path, 'bar')
      @stack.clear_git_cache!
      refute File.exist?(path)
    end

    test "#clear_git_cache! does nothing if the git directory is not present" do
      FileUtils.rm_rf(@stack.git_path)
      assert_nothing_raised do
        @stack.clear_git_cache!
      end
    end

    test "updating the stack emit a hook" do
      expect_hook(:stack, @stack, action: :updated, stack: @stack) do
        @stack.update(repo_name: 'foo')
      end
    end

    test "updating the stack doesn't emit a hook if only `updated_at` is changed" do
      # force a save to make sure `cached_deploy_spec` serialization is consistent with how Active Record would
      # serialize it.
      @stack.update(updated_at: 2.days.ago)

      expect_no_hook(:stack) do
        @stack.update(updated_at: Time.zone.now)
      end
    end

    test "#merge_status returns locked if stack is locked" do
      @stack.update!(lock_reason: 'Maintenance operation')
      assert_equal 'locked', @stack.merge_status
    end

    test "#merge_status returns state of last finalized undeployed commit" do
      @stack.deploys_and_rollbacks.destroy_all
      shipit_commits(:fifth).statuses.destroy_all
      shipit_commits(:fourth).statuses.update_all(state: 'pending')
      shipit_commits(:third).statuses.update_all(state: 'success')
      shipit_commits(:second).statuses.update_all(state: 'failure')

      assert_equal 'success', @stack.merge_status
    end

    test "#merge_status returns success if all undeployed commits and last deployed commit are in pending or unknown state" do
      shipit_commits(:fifth).statuses.destroy_all
      shipit_commits(:fourth).statuses.update_all(state: 'pending')
      shipit_commits(:third).statuses.update_all(state: 'pending')
      @stack.deploys_and_rollbacks.last.update!(status: 'success', until_commit: shipit_commits(:third))

      assert_equal 'success', @stack.merge_status
    end

    test "#merge_status returns success if there are no undeployed commits and no deployed commits" do
      @stack.deploys_and_rollbacks.last.update(status: 'success', until_commit: shipit_commits(:fifth))

      assert_equal 'success', @stack.merge_status
    end

    test "#merge_status returns backlogged if there are too many undeployed commits" do
      @stack.deploys_and_rollbacks.destroy_all
      @stack.update_undeployed_commits_count
      @stack.reload
      assert_equal 'backlogged', @stack.merge_status(backlog_leniency_factor: 1.5)
    end

    test "#merge_status returns success with a higher leniency factor" do
      @stack.deploys_and_rollbacks.destroy_all
      @stack.update_undeployed_commits_count
      @stack.reload
      assert_equal 'success', @stack.merge_status(backlog_leniency_factor: 3.0)
    end

    test "#handle_github_redirections update the stack if the repository was renamed" do
      repo_permalink = 'https://api.github.com/repositories/42'

      commits_redirection = stub(message: 'Moved Permanently', url: File.join(repo_permalink, '/commits'))
      Shipit.github.api.expects(:commits).with(@stack.github_repo_name, sha: 'master').returns(commits_redirection)

      repo_redirection = stub(message: 'Moved Permanently', url: repo_permalink)
      Shipit.github.api.expects(:repo).with('shopify/shipit-engine').returns(repo_redirection)

      repo_resource = stub(name: 'shipster', owner: stub(login: 'george'))
      Shipit.github.api.expects(:get).with(repo_permalink).returns(repo_resource)

      commits_resource = stub
      Shipit.github.api.expects(:commits).with('george/shipster', sha: 'master').returns(commits_resource)

      assert_equal 'shopify/shipit-engine', @stack.github_repo_name
      assert_equal commits_resource, @stack.github_commits
      @stack.reload
      assert_equal 'george/shipster', @stack.github_repo_name
    end

    test "#update_estimated_deploy_duration! records the 90th percentile duration among the last 100 deploys" do
      assert_equal 1, @stack.estimated_deploy_duration
      @stack.update_estimated_deploy_duration!
      assert_equal 120, @stack.estimated_deploy_duration
    end

    test "#trigger_continuous_delivery bails out if the stack isn't deployable" do
      Hook.stubs(:emit) # TODO: Once on rails 5, use assert_no_enqueued_jobs(only: Shipit::PerformTaskJob)

      @stack.lock('yada yada yada', AnonymousUser.new)
      refute_predicate @stack, :deployable?
      refute_predicate @stack, :deployed_too_recently?

      assert_no_enqueued_jobs do
        assert_no_difference -> { Deploy.count } do
          @stack.trigger_continuous_delivery
        end
      end
    end

    test "#trigger_continuous_delivery bails out if the stack is deployable but was deployed too recently" do
      Hook.stubs(:emit) # TODO: Once on rails 5, use assert_no_enqueued_jobs(only: Shipit::PerformTaskJob)

      @stack.tasks.delete_all
      deploy = @stack.trigger_deploy(shipit_commits(:first), AnonymousUser.new)
      deploy.run!
      deploy.complete!
      @stack.reload

      assert_predicate @stack, :deployable?
      assert_predicate @stack, :deployed_too_recently?

      assert_no_enqueued_jobs do
        assert_no_difference -> { Deploy.count } do
          @stack.trigger_continuous_delivery
        end
      end
    end

    test "#trigger_continuous_delivery bails out if the commit was already unsuccessfully deployed" do
      Hook.stubs(:emit) # TODO: Once on rails 5, use assert_no_enqueued_jobs(only: Shipit::PerformTaskJob)

      @stack.tasks.delete_all

      assert_predicate @stack, :deployable?
      refute_predicate @stack, :deployed_too_recently?

      commit = @stack.next_commit_to_deploy
      deploy = @stack.trigger_deploy(commit, AnonymousUser.new)
      deploy.error!
      assert_predicate commit, :deploy_failed?

      assert_no_enqueued_jobs do
        assert_no_difference -> { Deploy.count } do
          @stack.trigger_continuous_delivery
        end
      end
    end

    test "#trigger_continuous_delivery bails out if the previous deploy is still validating" do
      @stack = shipit_stacks(:shipit_canaries)
      shipit_tasks(:canaries_running).delete

      assert_predicate @stack, :deployable?
      assert_predicate @stack, :deployed_too_recently?
      assert_predicate @stack.last_active_task, :validating?

      assert_no_enqueued_jobs(only: Shipit::PerformTaskJob) do
        assert_no_difference -> { Deploy.count } do
          @stack.trigger_continuous_delivery
        end
      end

      @stack.last_active_task.complete!
      refute_predicate @stack, :deployed_too_recently?

      assert_enqueued_with(job: Shipit::PerformTaskJob) do
        assert_difference -> { Deploy.count }, +1 do
          @stack.trigger_continuous_delivery
        end
      end
    end

    test "#trigger_continuous_delivery bails out if no DeploySpec has been cached" do
      @stack = shipit_stacks(:check_deploy_spec)
      config = @stack.cached_deploy_spec.config

      assert_predicate @stack, :deployable?
      refute_predicate @stack, :deployed_too_recently?
      assert_empty(config, "DeploySpec was not empty")

      assert_no_enqueued_jobs(only: Shipit::PerformTaskJob) do
        assert_no_difference -> { Deploy.count } do
          @stack.trigger_continuous_delivery
        end
      end
    end

    test "#trigger_continuous_delivery enqueues deployment ref update job" do
      @stack = shipit_stacks(:shipit_canaries)
      shipit_tasks(:canaries_running).delete

      assert_no_enqueued_jobs(only: Shipit::UpdateGithubLastDeployedRefJob) do
        assert_no_difference -> { Deploy.count } do
          @stack.trigger_continuous_delivery
        end
      end

      assert_enqueued_with(job: Shipit::UpdateGithubLastDeployedRefJob, args: [@stack]) do
        @stack.last_active_task.complete!
      end
    end

    test "#trigger_continuous_delivery executes ref update job with correct sha" do
      @stack = shipit_stacks(:shipit_canaries)
      shipit_tasks(:canaries_running).delete

      assert_no_enqueued_jobs(only: Shipit::UpdateGithubLastDeployedRefJob) do
        assert_no_difference -> { Deploy.count } do
          @stack.trigger_continuous_delivery
        end
      end

      desired_last_commit_sha = @stack.last_active_task.until_commit.sha
      Shipit.github.api.expects(:update_ref).with(anything, anything, desired_last_commit_sha).returns("test")

      perform_enqueued_jobs(only: Shipit::UpdateGithubLastDeployedRefJob) do
        @stack.last_active_task.complete!
      end
    end

    test "#trigger_continuous_delivery trigger a deploy if all conditions are met" do
      @stack.tasks.delete_all
      assert_predicate @stack, :deployable?
      refute_predicate @stack, :deployed_too_recently?

      assert_difference -> { Deploy.count }, +1 do
        @stack.trigger_continuous_delivery
      end
    end

    test "#trigger_continuous_delivery use default env vars" do
      @stack.tasks.delete_all

      deploy = @stack.trigger_continuous_delivery
      assert_equal({'SAFETY_DISABLED' => '0'}, deploy.env)
    end

    test "#continuous_delivery_delayed! bumps updated_at" do
      old_updated_at = @stack.updated_at - 3.minutes
      @stack.update_column(:updated_at, old_updated_at)
      @stack.reload

      @stack.continuous_delivery_delayed!

      assert_not_equal old_updated_at, @stack.updated_at
    end

    test "#next_commit_to_deploy returns the last deployable commit" do
      @stack.tasks.where.not(until_commit_id: shipit_commits(:second).id).destroy_all
      assert_equal shipit_commits(:second), @stack.last_deployed_commit

      assert_equal shipit_commits(:third), @stack.next_commit_to_deploy

      fifth_commit = shipit_commits(:fifth)
      fifth_commit.statuses.create!(stack_id: @stack.id, state: 'success', context: 'ci/travis')
      assert_predicate fifth_commit, :deployable?

      assert_equal shipit_commits(:fifth), @stack.next_commit_to_deploy
    end

    test "#next_commit_to_deploy respects the deploy.max_commits directive" do
      @stack.tasks.destroy_all

      fifth_commit = shipit_commits(:third)
      fifth_commit.statuses.create!(stack_id: @stack.id, state: 'success', context: 'ci/travis')
      assert_predicate fifth_commit, :deployable?

      assert_equal shipit_commits(:third), @stack.next_commit_to_deploy

      @stack.expects(:maximum_commits_per_deploy).returns(3).at_least_once
      assert_equal shipit_commits(:third), @stack.next_commit_to_deploy
    end

    test "setting #lock_reason also sets #locked_since" do
      assert_predicate @stack.locked_since, :nil?

      @stack.update!(lock_reason: "Here comes the walrus")
      refute_predicate @stack.locked_since, :nil?

      @stack.update!(lock_reason: nil)
      assert_predicate @stack.locked_since, :nil?
    end

    test "updating #lock_reason preserves #locked_since" do
      @stack.update!(lock_reason: "Here comes the walrus")
      expected = @stack.locked_since

      @stack.update!(lock_reason: "The walrus strikes back")
      assert_equal expected, @stack.locked_since
    end

    test "#lock sets reason and user" do
      reason = "Here comes the walrus"
      user = shipit_users(:walrus)
      @stack.lock(reason, user)
      assert @stack.locked?
      assert_equal reason, @stack.lock_reason
      assert_equal user, @stack.lock_author
    end

    test "#lock can set a reason code" do
      reason = "Here comes the walrus"
      user = shipit_users(:walrus)
      code = "STUFF"
      @stack.lock(reason, user, code: code)
      assert @stack.locked?
      assert_equal code, @stack.lock_reason_code
      assert_equal [@stack], Shipit::Stack.locked_because(code).all
    end

    test "#unlock deletes reason, user & reason code" do
      user = shipit_users(:walrus)
      @stack.lock("Here comes the walrus", user, code: "STUFF")
      @stack.unlock
      refute @stack.locked?
      assert_nil @stack.lock_reason
      assert_nil @stack.lock_reason_code
      assert_not_equal user, @stack.lock_author
    end

    test "stacks can be marked auto-provisioned" do
      @stack.update!(auto_provisioned: true)
      assert @stack.auto_provisioned?
    end

    test "auto-provisioned stacks can be listed" do
      @stack.update!(auto_provisioned: true)
      assert_equal [@stack], Shipit::Stack.auto_provisioned
    end

    test "stack contains valid deploy_url" do
      @stack.deploy_url = "Javascript:alert(0);//"
      assert_not_predicate @stack, :valid?
      @stack.deploy_url = "https://shopify.com"
      assert_predicate @stack, :valid?
      @stack.deploy_url = "ssh://abc"
      assert_predicate @stack, :valid?
    end

    test "#ci_enabled? is true if there are any commits with a status" do
      Shipit::CheckRun.where(stack_id: @stack.id).delete_all
      Rails.cache.clear

      assert_predicate Shipit::Status.where(stack_id: @stack.id), :any?
      assert @stack.ci_enabled?
    end

    test "#ci_enabled? is true if there are any check runs" do
      Shipit::Status.where(stack_id: @stack.id).delete_all
      Rails.cache.clear

      assert_predicate Shipit::CheckRun.where(stack_id: @stack.id), :any?
      assert_predicate @stack, :ci_enabled?
    end

    test "#ci_enabled? is false if there are no check_runs or statuses" do
      Shipit::Status.where(stack_id: @stack.id).delete_all
      Shipit::CheckRun.where(stack_id: @stack.id).delete_all

      Rails.cache.clear
      refute_predicate @stack, :ci_enabled?
    end

    test "#undeployed_commits returns list of commits newer than last deployed commit" do
      @stack = shipit_stacks(:shipit_undeployed)
      last_deployed_commit = @stack.last_deployed_commit
      commits = @stack.undeployed_commits

      assert_equal @stack.undeployed_commits_count, commits.size

      commits.each { |c| assert c.id > last_deployed_commit.id }
    end

    test "#next_expected_commit_to_deploy returns nil if there is no deployable commit" do
      commits = @stack.undeployed_commits

      assert !commits.empty?
      commits.each { |c| refute_predicate c, :deployable? }

      assert_nil @stack.next_expected_commit_to_deploy(commits: commits)
    end

    test "#next_expected_commit_to_deploy returns nil if all deployable commits are active" do
      @stack = shipit_stacks(:shipit_undeployed)
      commits = @stack.undeployed_commits.select(&:active?)

      assert !commits.empty?
      commits.each { |c| assert_predicate c, :active? }

      assert_nil @stack.next_expected_commit_to_deploy(commits: commits)
    end

    test "#next_expected_commit_to_deploy returns nil if there are no commits" do
      assert_nil @stack.next_expected_commit_to_deploy(commits: [])
    end

    test "#next_expected_commit_to_deploy returns the most recent non-active deployable commit limited by maximum commits per deploy" do
      @stack = shipit_stacks(:shipit_undeployed)
      commits = @stack.undeployed_commits

      assert !commits.empty?

      most_recent_limited = @stack.next_expected_commit_to_deploy(commits: commits)
      most_recent = commits.find { |c| !c.active? && c.deployable? }

      assert most_recent.id > most_recent_limited.id
      assert_equal @stack.maximum_commits_per_deploy, commits.find_index(most_recent_limited) + 1
    end

    test "#async_refresh_deployed_revision suppresses and logs raised exception" do
      error_message = "Error message"

      Rails.logger.expects(:warn).with("Failed to dispatch FetchDeployedRevisionJob: [StandardError] #{error_message}")
      @stack.expects(:async_refresh_deployed_revision!).raises(StandardError.new(error_message))

      @stack.async_refresh_deployed_revision
    end

    test "#lock_reverted_commits! locks all commits between the original and reverted commits" do
      reverted_commit = @stack.undeployed_commits.first
      revert_author = shipit_users(:bob)
      generate_revert_commit(stack: @stack, reverted_commit: reverted_commit, author: revert_author)
      @stack.reload

      assert_equal(
        [
          ['Revert "whoami"', false, nil],
          ["whoami", false, nil],
          ["fix all the things", false, nil],
        ],
        @stack.undeployed_commits.map { |c| [c.message, c.locked, c.lock_author_id] },
      )

      @stack.lock_reverted_commits!
      @stack.reload

      assert_equal(
        [
          ['Revert "whoami"', false, nil],
          ["whoami", true, revert_author.id],
          ["fix all the things", false, nil],
        ],
        @stack.undeployed_commits.map { |c| [c.message, c.locked, c.lock_author_id] },
      )
    end

    test "#lock_reverted_commits! is a no-op if the reverted commit has already shipped" do
      reverted_commit = shipit_commits(:first)
      revert_author = shipit_users(:bob)
      generate_revert_commit(stack: @stack, reverted_commit: reverted_commit, author: revert_author)
      @stack.reload

      initial_state = [
        ['Revert "lets go"', false, nil],
        ["whoami", false, nil],
        ["fix all the things", false, nil],
      ]

      assert_equal(
        initial_state,
        @stack.undeployed_commits.map { |c| [c.message, c.locked, c.lock_author_id] },
      )

      @stack.lock_reverted_commits!
      @stack.reload

      assert_equal(
        initial_state,
        @stack.undeployed_commits.map { |c| [c.message, c.locked, c.lock_author_id] },
      )
    end

    test "#lock_reverted_commits! handles multiple reverts" do
      first_reverted_commit = @stack.undeployed_commits.last
      second_reverted_commit = @stack.undeployed_commits.first
      first_revert_author = shipit_users(:bob)
      second_revert_author = shipit_users(:walrus)
      generate_revert_commit(stack: @stack, reverted_commit: first_reverted_commit, author: first_revert_author)
      generate_revert_commit(stack: @stack, reverted_commit: second_reverted_commit, author: second_revert_author)
      @stack.reload

      assert_equal(
        [
          ['Revert "whoami"', false, nil],
          ['Revert "fix all the things"', false, nil],
          ["whoami", false, nil],
          ["fix all the things", false, nil],
        ],
        @stack.undeployed_commits.map { |c| [c.message, c.locked, c.lock_author_id] },
      )

      @stack.lock_reverted_commits!
      @stack.reload

      assert_equal(
        [
          ['Revert "whoami"', false, nil],
          ['Revert "fix all the things"', true, second_revert_author.id],
          ["whoami", true, first_revert_author.id],
          ["fix all the things", true, first_revert_author.id],
        ],
        @stack.undeployed_commits.map { |c| [c.message, c.locked, c.lock_author_id] },
      )
    end

    test "#trigger_continuous_delivery sets delay if commit was pushed recently" do
      freeze_time do
        @stack.tasks.delete_all

        commit = @stack.next_commit_to_deploy
        commit.touch(:created_at)

        assert_no_enqueued_jobs(only: Shipit::PerformTaskJob) do
          assert_no_difference -> { Deploy.count } do
            @stack.trigger_continuous_delivery
          end
        end
      end
    end

    test "#links performs template substitutions" do
      @stack.repo_name = "expected-repository-name"
      @stack.environment = "expected-environment"
      @stack.cached_deploy_spec = create_deploy_spec(
        "links" => {
          "logs" => "http://logs.$GITHUB_REPO_NAME.$ENVIRONMENT.domain.com",
          "monitoring" => "https://graphs.$GITHUB_REPO_NAME.$ENVIRONMENT.domain.com",
        },
      )

      assert_equal(
        {
          "logs" => "http://logs.expected-repository-name.expected-environment.domain.com",
          "monitoring" => "https://graphs.expected-repository-name.expected-environment.domain.com",
        },
        @stack.links,
      )
    end

    test "#env includes the stack's environment" do
      expected_environment = {
        'ENVIRONMENT' => @stack.environment,
        'LAST_DEPLOYED_SHA' => @stack.last_deployed_commit.sha,
        'GITHUB_REPO_OWNER' => @stack.repository.owner,
        'GITHUB_REPO_NAME' => @stack.repository.name,
        'DEPLOY_URL' => @stack.deploy_url,
        'BRANCH' => @stack.branch,
      }

      assert_equal(
        @stack.env,
        expected_environment,
      )
    end

    private

    def generate_revert_commit(stack:, reverted_commit:, author: reverted_commit.author)
      stack.commits.create(
        sha: SecureRandom.hex(20),
        message: "Revert \"#{reverted_commit.message_header}\"",
        author: author,
        committer: author,
        authored_at: Time.zone.now,
        committed_at: Time.zone.now,
      )
    end

    def create_deploy_spec(spec)
      Shipit::DeploySpec.new(spec.stringify_keys)
    end
  end
end
