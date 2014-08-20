require 'test_helper'

class StacksTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @expected_base_path = File.join(Rails.root, "data", "stacks", @stack.repo_owner, @stack.repo_name, @stack.environment)
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
    assert_equal @expected_base_path, @stack.base_path
  end

  test "deploys_path" do
    assert_equal File.join(@expected_base_path, "deploys"), @stack.deploys_path
  end

  test "git_path" do
    assert_equal File.join(@expected_base_path, "git"), @stack.git_path
  end

  test "old_undeployed_commits returns commits that were created before the specified time" do
    last_commit = Commit.last
    last_commit.created_at = 4.hours.ago
    last_commit.save
    old_undeployed_commits = @stack.old_undeployed_commits(long_time_ago = 3.hours.ago)
    assert_equal [last_commit.id], old_undeployed_commits.pluck(:id)
  end

  test "reminder_url cannot be set to an invalid URL" do
    invalid_urls = %w(
      example
      ftp://username@example.com/
      http://
      http://test
      .com
    )

    invalid_urls.each do |invalid_url|
      @stack.reminder_url = invalid_url
      assert_equal false, @stack.valid?
    end
  end

  test "reminder_url can be set to a valid URL" do
    valid_urls = %w(
      example.com
      www.example.com
      http://example.ca
      http://example-store.ca
      https://example.com
      https://example.com/some/path
      https://example.com:80
      https://user:password@examine-website.ca:3001
    )

    valid_urls.each do |valid_url|
      @stack.reminder_url = valid_url
      assert_equal true, @stack.valid?
    end
  end

  test "reminder_url can set to blank" do
    @stack.reminder_url = ""
    assert_equal true, @stack.valid?
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

  test "#create queues a GithubSetupWebhooksJob and a GithubSyncJob" do
    Resque.expects(:enqueue).with(GithubSetupWebhooksJob, has_key(:stack_id))
    Resque.expects(:enqueue).with(GithubSyncJob, has_key(:stack_id))
    Stack.create( repo_name: 'rails', repo_owner: 'rails' )
  end

  test "#destroy queues a GithubTeardownWebhooksJob" do
    Resque.expects(:enqueue).with(GithubTeardownWebhooksJob, all_of(has_key(:stack_id), has_key(:github_repo_name)))
    stacks(:shipit).destroy
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

  test ".sharded allow to reduce the set of records based on the primary key" do
    assert_equal [], Stack.sharded(2, 0).pluck(:id)
    assert_equal [@stack.id], Stack.sharded(2, 1).pluck(:id)
  end

  test ".sharded check arguments" do
    assert_raises ArgumentError do
      Stack.sharded(2, 2)
    end

    assert_raises ArgumentError do
      Stack.sharded(0, 0)
    end
  end

end
