require 'test_helper'

class DeploysTest < ActiveSupport::TestCase

  def setup
    @deploy = deploys(:shipit)
  end

  test "enqueue" do
    Resque.expects(:enqueue).with(DeployJob, deploy_id: @deploy.id, stack_id: @deploy.id)

    @deploy.enqueue
  end

  test "enqueue when not persisted" do
    assert_raise(RuntimeError) { Deploy.new.enqueue }
  end

  test "working_directory" do
    assert_equal File.join(@deploy.stack.deploys_path, @deploy.id.to_s), @deploy.working_directory
  end

  test "#since_commit_id returns the database value if present" do
    @deploy.expects(:read_attribute).with(:since_commit_id).returns(1)
    assert_equal 1, @deploy.since_commit_id
  end

  test "#since_commit_id returns nil if stack_id isn't set" do
    deploy = Deploy.new
    assert_nil deploy.since_commit_id
  end

  test "#since_commit_id returns a default value if stack_id is set" do
    stack  = stacks(:shipit)
    deploy = stack.deploys.new
    last   = stack.deploys.success.last.until_commit_id
    assert_equal last, deploy.since_commit_id
  end

  test "#commits returns empty array if stack isn't set" do
    @deploy.expects(:stack).returns(nil)
    assert_equal [], @deploy.commits
  end

  test "#commits returns the commits in the id range" do
    stack = stacks(:shipit)
    first = commits(:first)
    last  = commits(:third)

    deploy = stack.deploys.new(
      :since_commit => first,
      :until_commit => last
    )

    commits = deploy.commits

    assert_not_empty commits
    assert_equal last.id, commits.map(&:id).max
    assert_not_equal first.id, commits.map(&:id).min
  end

  test "#commits returns commits from newer to older" do
    stack = stacks(:shipit)
    first = commits(:first)
    last  = commits(:fourth)

    deploy = stack.deploys.new(
      :since_commit => first,
      :until_commit => last
    )

    assert_equal [4, 3, 2], deploy.commits.pluck(:id)
  end

  test "transitioning away from the pending state enqueues a ChunkRollupJob" do
    deploy = deploys(:shipit_pending)
    Resque.expects(:enqueue).with(ChunkRollupJob, deploy_id: deploy.id)
    deploy.run! && deploy.complete!
  end

  test "transitioning to success causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_event(deploy, "success")
    deploy.status = 'running'
    deploy.complete!
  end

  test "transitioning to failed causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_event(deploy, "failed")
    deploy.status = 'running'
    deploy.failure!
  end

  test "transitioning to error causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_event(deploy, "error")
    deploy.status = 'running'
    deploy.error!
  end

  test "transitioning to running causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_event(deploy, "running")
    deploy.status = 'pending'
    deploy.run!
  end

  test "creating a deploy causes an event to be broadcasted" do
    shipit = stacks(:shipit)
    deploy = shipit.deploys.build(
      since_commit: shipit.commits.first,
      until_commit: shipit.commits.last
    )

    expect_event(deploy, "pending")
    deploy.save!
  end

  test "transitioning to success triggers next deploy when stack uses CD" do
    commits(:fifth).update_column(:state, 'success')

    deploy = deploys(:shipit_running)
    deploy.stack.update(continuous_deployment: true)

    assert_difference "Deploy.count" do
      deploy.complete
    end
  end

  test "transitioning to success skips CD deploy when stack doesn't use it" do
    commits(:fifth).update_column(:state, 'success')

    deploy = deploys(:shipit_running)

    assert_no_difference "Deploy.count" do
      deploy.complete
    end
  end

  test "transitioning to success skips CD when no successful commits after until_commit" do
    deploy = deploys(:shipit_running)
    deploy.stack.update(continuous_deployment: true)

    assert_no_difference "Deploy.count" do
      deploy.complete
    end
  end

  test "#transitioning to success update the undeployed_commits_count" do
    stack  = stacks(:shipit)
    deploy = stack.deploys.active.first
    assert_equal 3, stack.undeployed_commits_count

    deploy.run!
    deploy.complete!

    stack.reload
    assert_equal 1, stack.undeployed_commits_count
  end

  test "#push_github_status create the remove deploy on the fly if needed" do
    Shipit.github_api.expects(:create_deployment).with('Shopify/shipit', 'master')
  end

  def expect_event(deploy, status)
    Pubsubstub::RedisPubSub.expects(:publish).with do |channel, event|
      data = JSON.load(event.data)
      channel == "stack.#{deploy.stack.id}" &&
      event.name == "deploy.#{status}" &&
      data['url'].match(%r{#{deploy.stack.to_param}/deploys/#{deploy.id || "\\d"}}) &&
      data['commit_ids'] == deploy.commits.pluck(:id)
    end
  end
end


class NonTransationnalDeploysTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = false

  test "#event transition trigger a GithubDeployStatusJob" do
    commits(:fifth).update_column(:state, 'success')

    deploy = deploys(:shipit_running)
    Resque.expects(:enqueue).at_least_once
    Resque.expects(:enqueue).with(GithubDeployStatusJob, deploy_id: deploy.id, status: 'success')
    deploy.complete!
  end
end
