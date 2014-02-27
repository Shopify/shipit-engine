require 'test_helper'

class StacksTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @expected_base_path = File.join(Rails.root, "data", "stacks", @stack.repo_owner, @stack.repo_name, @stack.environment)
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

  test "#trigger_deploy persist a new deploy" do
    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit)
    assert deploy.persisted?
    assert_equal last_commit.id, deploy.until_commit_id
    assert_equal deploys(:shipit).until_commit_id, deploy.since_commit_id
  end

  test "#trigger_deploy deploy until the commit passed in argument" do
    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit)
    assert_equal last_commit.id, deploy.until_commit_id
  end

  test "#trigger_deploy since_commit is the last deploy until_commit if there is a previous deploy" do
    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit)
    assert_equal deploys(:shipit).until_commit_id, deploy.since_commit_id
  end

  test "#trigger_deploy since_commit is the first stack commit if there is no previous deploy" do
    @stack.deploys.destroy_all

    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit)
    assert_equal @stack.commits.first.id, deploy.since_commit_id
  end

  test "#trigger_deploy enqueue  a deploy job" do
    @stack.deploys.destroy_all

    Resque.expects(:enqueue).with(DeployJob, instance_of(Hash))

    last_commit = commits(:third)
    deploy = @stack.trigger_deploy(last_commit)
  end

  test "creating a stack queues a GithubSetupWebhooksJob" do
    Resque.expects(:enqueue).with(GithubSetupWebhooksJob, has_key(:stack_id))
    stack = Stack.create(repo_owner: "Shopify", repo_name: "Unicorns", environment: :production, branch: :master)
  end

  test "destroying a stack queues a GithubTeardownWebhooksJob" do
    Resque.expects(:enqueue).with(GithubTeardownWebhooksJob, has_key(:stack_id))
    stacks(:shipit).destroy
  end
end
