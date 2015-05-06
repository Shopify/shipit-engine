require 'test_helper'

class StacksTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @expected_base_path = Rails.root.join('data/stacks', @stack.to_param).to_s
    GithubHook.any_instance.stubs(:teardown!)
  end

  test "repo_owner, repo_name and environment uniqueness is enforced" do
    clone = Stack.new(@stack.attributes.except('id'))
    refute clone.save
    assert_equal ["has already been taken"], clone.errors[:repo_name]
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
    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
    assert deploy.persisted?
    assert_equal last_commit.id, deploy.until_commit_id
    assert_equal deploys(:shipit).until_commit_id, deploy.since_commit_id
  end

  test "#trigger_deploy deploy until the commit passed in argument" do
    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
    assert_equal last_commit.id, deploy.until_commit_id
  end

  test "#trigger_deploy since_commit is the last completed deploy until_commit if there is a previous deploy" do
    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
    assert_equal deploys(:shipit).until_commit_id, deploy.since_commit_id
  end

  test "#trigger_deploy since_commit is the first stack commit if there is no previous deploy" do
    @stack.deploys.destroy_all

    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
    assert_equal @stack.commits.first.id, deploy.since_commit_id
  end

  test "#trigger_deploy enqueue  a deploy job" do
    @stack.deploys.destroy_all
    Deploy.any_instance.expects(:enqueue).once

    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit, AnonymousUser.new)
    assert_instance_of Deploy, deploy
  end

  test "#update_deployed_revision bail out if there is an active deploy" do
    assert_no_difference 'Deploy.count' do
      @stack.update_deployed_revision(commits(:fifth).sha)
    end
  end

  test "#update_deployed_revision bail out if sha is unknown" do
    assert_no_difference 'Deploy.count' do
      @stack.update_deployed_revision('skldjaslkdjas')
    end
  end

  test "#update_deployed_revision create a new completed deploy" do
    Deploy.active.update_all(status: 'error')

    assert_equal commits(:second), @stack.last_deployed_commit
    assert_difference 'Deploy.count', +1 do
      deploy = @stack.update_deployed_revision(commits(:fifth).sha)
      assert_not_nil deploy
      assert_equal commits(:second), deploy.since_commit
      assert_equal commits(:fifth), deploy.until_commit
    end
    assert_equal commits(:fifth), @stack.last_deployed_commit
  end

  test "#update_deployed_revision works with short shas" do
    Deploy.active.update_all(status: 'error')

    assert_equal commits(:second), @stack.last_deployed_commit
    assert_difference 'Deploy.count', +1 do
      deploy = @stack.update_deployed_revision(commits(:fifth).sha[0..5])
      assert_not_nil deploy
      assert_equal commits(:second), deploy.since_commit
      assert_equal commits(:fifth), deploy.until_commit
    end
    assert_equal commits(:fifth), @stack.last_deployed_commit
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
      stacks(:shipit).destroy
    end
  end

  test "#destroy delete all local files (git mirror and deploy clones)" do
    FileUtils.expects(:rm_rf).with(Rails.root.join('data', 'stacks', 'shopify', 'shipit2', 'production').to_s)
    stacks(:shipit).destroy
  end

  test "#deploying? is false if stack has no deploy in either pending or running state" do
    @stack.deploys.active.destroy_all
    refute @stack.deploying?
  end

  test "#deploying? is false if stack has no deploy at all" do
    @stack.deploys.destroy_all
    refute @stack.deploying?
  end

  test "#deploying? is true if stack has a deploy in either pending or running state" do
    @stack.trigger_deploy(commits(:third), AnonymousUser.new)
    assert @stack.deploying?
  end

  test "#deploying? is memoized" do
    assert_queries(1) do
      10.times { @stack.deploying? }
    end
  end

  test "#deploying? cache is cleared if a deploy change state" do
    assert_queries(1) do
      10.times { @stack.deploying? }
    end
    @stack.tasks.where(status: 'running').first.error!
    assert_queries(1) do
      10.times { @stack.deploying? }
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
    @stack.trigger_deploy(commits(:third), AnonymousUser.new)
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
    expect_hook(:lock, @stack, locked: true, stack: @stack)
    @stack.update(lock_reason: "Just for fun", lock_author: users(:walrus))
  end

  test "unlocking the stack triggers a webhook" do
    @stack.update(lock_reason: "Just for fun", lock_author: users(:walrus))
    expect_hook(:lock, @stack, locked: false, stack: @stack)
    @stack.update(lock_reason: nil)
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
    stacks(:cyclimse).acquire_git_cache_lock do
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

  private

  def expect_hook(event, stack, payload)
    Hook.expects(:emit).with(event, stack, payload)
  end
end
