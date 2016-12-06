require 'test_helper'

module Shipit
  class StacksTest < ActiveSupport::TestCase
    def setup
      @stack = shipit_stacks(:shipit)
      @expected_base_path = Rails.root.join('data/stacks', @stack.to_param).to_s
      GithubHook.any_instance.stubs(:teardown!)
    end

    test "repo_owner, repo_name and environment uniqueness is enforced" do
      clone = Stack.new(@stack.attributes.except('id'))
      refute clone.save
      assert_equal ["cannot be used more than once with this environment"], clone.errors[:repo_name]
    end

    test "repo_owner, repo_name, and environment can only be ASCII" do
      @stack.update(repo_owner: 'héllò', repo_name: 'wørld', environment: 'pródüctïòn')
      refute_predicate @stack, :valid?
    end

    test "repo_owner and repo_name are case insensitive" do
      assert_no_difference -> { Stack.count } do
        error = assert_raises ActiveRecord::RecordInvalid do
          Stack.create!(
            repo_owner: @stack.repo_owner.upcase,
            repo_name: @stack.repo_name.upcase,
            environment: @stack.environment,
          )
        end
        assert_equal 'Validation failed: Repo name cannot be used more than once with this environment', error.message
      end

      new_stack = Stack.create!(repo_owner: 'FOO', repo_name: 'BAR')
      assert_equal new_stack, Stack.find_by(repo_owner: 'foo', repo_name: 'bar')
    end

    test "repo_owner is automatically downcased" do
      @stack.repo_owner = 'George'
      assert_equal 'george', @stack.repo_owner
    end

    test "repo_name is automatically downcased" do
      @stack.repo_name = 'Cyclim.se'
      assert_equal 'cyclim.se', @stack.repo_name
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

    test "repo_owner cannot contain a `/`" do
      assert @stack.valid?
      @stack.repo_owner = 'foo/bar'
      refute @stack.valid?
    end

    test "repo_name cannot contain a `/`" do
      assert @stack.valid?
      @stack.repo_name = 'foo/bar'
      refute @stack.valid?
    end

    test "repo_http_url" do
      assert_equal "https://github.com/#{@stack.repo_owner}/#{@stack.repo_name}", @stack.repo_http_url
    end

    test "repo_git_url" do
      assert_equal "git@github.com:#{@stack.repo_owner}/#{@stack.repo_name}.git", @stack.repo_git_url
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

    test "#trigger_deploy enqueue  a deploy job" do
      @stack.deploys.destroy_all
      Deploy.any_instance.expects(:enqueue).once

      last_commit = shipit_commits(:third)
      deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
      assert_instance_of Deploy, deploy
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

    test "#create queues 2 GithubSetupWebhooksJob" do
      assert_enqueued_with(job: SetupGithubHookJob) do
        Stack.create!(repo_name: 'rails', repo_owner: 'rails')
      end
    end

    test "#create queues a GithubSyncJob" do
      assert_enqueued_with(job: GithubSyncJob) do
        Stack.create!(repo_name: 'rails', repo_owner: 'rails')
      end
    end

    test "#destroy also destroy associated GithubHooks" do
      assert_difference -> { GithubHook.count }, -2 do
        shipit_stacks(:shipit).destroy
      end
    end

    test "#destroy also destroy associated Commits" do
      assert_difference -> { Commit.count }, -5 do
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

    test "#active_task? is memoized" do
      assert_queries(1) do
        10.times { @stack.active_task? }
      end
    end

    test "#deployable? returns true if stack is not locked and is not deploying" do
      @stack.deploys.destroy_all
      assert @stack.deployable?
    end

    test "#deployable? returns false if stack is locked" do
      @stack.update!(lock_reason: 'Maintenance operation')
      refute @stack.deployable?
    end

    test "#deployable? returns false if stack is deploying" do
      @stack.trigger_deploy(shipit_commits(:third), AnonymousUser.new)
      refute @stack.deployable?
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
      expect_hook(:lock, @stack, locked: true, stack: @stack) do
        @stack.update(lock_reason: "Just for fun", lock_author: shipit_users(:walrus))
      end
    end

    test "unlocking the stack triggers a webhook" do
      @stack.update(lock_reason: "Just for fun", lock_author: shipit_users(:walrus))
      expect_hook(:lock, @stack, locked: false, stack: @stack) do
        @stack.update(lock_reason: nil)
      end
    end

    test "the git cache lock prevent concurrent access to the git cache" do
      @stack.acquire_git_cache_lock do
        assert_raises Redis::Lock::LockTimeout do
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

    test "#filter_visible_statuses removes statuses from hidden contexts" do
      stack = shipit_stacks(:cyclimse)
      stack.stubs(hidden_statuses: ['ci/hidden'])
      commit1 = Status.new(state: 'pending', context: 'ci/valid')
      commit2 = Status.new(state: 'pending', context: 'ci/valid')
      hidden = Status.new(state: 'pending', context: 'ci/hidden')

      assert_equal [commit1, commit2], stack.filter_visible_statuses([hidden, commit1, commit2])
    end

    test "#filter_meaningful_statuses removes statuses from soft-failing contexts" do
      stack = shipit_stacks(:cyclimse)
      stack.stubs(soft_failing_statuses: ['ci/soft-fail'])
      commit1 = Status.new(state: 'pending', context: 'ci/valid')
      commit2 = Status.new(state: 'pending', context: 'ci/valid')
      soft_fail = Status.new(state: 'pending', context: 'ci/soft-fail')

      assert_equal [commit1, commit2], stack.filter_meaningful_statuses([soft_fail, commit1, commit2])
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

    test "#merge_status returns pending if all undeployed commits and last deployed commit are in pending or unknown state" do
      shipit_commits(:fifth).statuses.destroy_all
      shipit_commits(:fourth).statuses.update_all(state: 'pending')
      shipit_commits(:third).statuses.update_all(state: 'pending')
      @stack.deploys_and_rollbacks.last.update!(status: 'success', until_commit: shipit_commits(:third))

      assert_equal 'pending', @stack.merge_status
    end

    test "#merge_status returns pending if there are no undeployed commits and no deployed commits" do
      @stack.deploys_and_rollbacks.last.update(status: 'success', until_commit: shipit_commits(:fifth))

      assert_equal 'pending', @stack.merge_status
    end

    test "#merge_status returns state of last deployed commit if there are no undeployed commits waiting" do
      shipit_commits(:fifth).statuses.destroy_all
      @stack.deploys_and_rollbacks.last.update!(status: 'success', until_commit: shipit_commits(:fourth))

      shipit_commits(:fourth).statuses.update_all(state: 'success')
      assert_equal 'success', @stack.merge_status

      shipit_commits(:fourth).statuses.last.update(state: 'failure')
      assert_equal 'failure', @stack.merge_status
    end

    test "#merge_status returns state of last deployed commit if all undeployed commits are in pending or unknown state" do
      shipit_commits(:fifth).statuses.destroy_all
      shipit_commits(:fourth).statuses.update_all(state: 'pending')
      @stack.deploys_and_rollbacks.last.update!(status: 'success', until_commit: shipit_commits(:third))

      shipit_commits(:third).statuses.update_all(state: 'success')
      assert_equal 'success', @stack.merge_status

      shipit_commits(:third).statuses.last.update(state: 'failure')
      assert_equal 'failure', @stack.merge_status
    end

    test "#handle_github_redirections update the stack if the repository was renamed" do
      repo_permalink = 'https://api.github.com/repositories/42'

      commits_redirection = stub(message: 'Moved Permanently', url: File.join(repo_permalink, '/commits'))
      Shipit.github_api.expects(:commits).with(@stack.github_repo_name, sha: 'master').returns(commits_redirection)

      repo_redirection = stub(message: 'Moved Permanently', url: repo_permalink)
      Shipit.github_api.expects(:repo).with('shopify/shipit-engine').returns(repo_redirection)

      repo_resource = stub(name: 'shipster', owner: stub(login: 'george'))
      Shipit.github_api.expects(:get).with(repo_permalink).returns(repo_resource)

      commits_resource = stub
      Shipit.github_api.expects(:commits).with('george/shipster', sha: 'master').returns(commits_resource)

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

      fifth_commit = shipit_commits(:fifth)
      fifth_commit.statuses.create!(stack_id: @stack.id, state: 'success', context: 'ci/travis')
      assert_predicate fifth_commit, :deployable?

      assert_equal shipit_commits(:fifth), @stack.next_commit_to_deploy

      @stack.expects(:maximum_commits_per_deploy).returns(3).at_least_once
      assert_equal shipit_commits(:third), @stack.next_commit_to_deploy
    end

    test "#lock sets reason, user and locked_since" do
      reason = "Here comes the walrus"
      user = shipit_users(:walrus)
      @stack.lock(reason, user)
      assert @stack.locked?
      assert_equal reason, @stack.lock_reason
      assert_equal user, @stack.lock_author
      assert_not_nil user, @stack.locked_since
    end

    test "#unlock deletes reason, user and locked_since" do
      user = shipit_users(:walrus)
      @stack.lock("Here comes the walrus", user)
      @stack.unlock
      refute @stack.locked?
      assert_nil @stack.lock_reason
      assert_nil @stack.locked_since
      assert_not_equal user, @stack.lock_author
    end

    test "#lock does not overwrite locked_since if already locked" do
      @stack.lock("Here comes the walrus", shipit_users(:walrus))
      old_time = @stack.locked_since

      new_reason = "Its still coming!"
      @stack.lock(new_reason, shipit_users(:walrus))

      assert @stack.locked?
      assert_equal new_reason, @stack.lock_reason
      assert_equal old_time, @stack.locked_since
    end

    test "stack contains valid deploy_url" do
      @stack.deploy_url = "Javascript:alert(0);//"
      assert_not_predicate @stack, :valid?
      @stack.deploy_url = "https://shopify.com"
      assert_predicate @stack, :valid?
      @stack.deploy_url = "ssh://abc"
      assert_predicate @stack, :valid?
    end
  end
end
