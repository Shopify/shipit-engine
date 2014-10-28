require 'test_helper'

class DeploysTest < ActiveSupport::TestCase
  def setup
    @deploy = deploys(:shipit)
  end

  test "#rollback? returns false" do
    refute @deploy.rollback?
  end

  test "enqueue" do
    Resque.expects(:enqueue).with(PerformTaskJob, task_id: @deploy.id, stack_id: @deploy.id)

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

  test "additions and deletions are denormalized on before create" do
    stack = stacks(:shipit)
    first = commits(:first)
    third  = commits(:third)

    deploy = stack.deploys.create!(
      :since_commit => first,
      :until_commit => third
    )

    assert_equal 13, deploy.additions
    assert_equal 65, deploy.deletions
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

  test "transitioning to success causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_event(deploy)
    deploy.status = 'running'
    deploy.complete!
  end

  test "transitioning to failed causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_event(deploy)
    deploy.status = 'running'
    deploy.failure!
  end

  test "transitioning to error causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_event(deploy)
    deploy.status = 'running'
    deploy.error!
  end

  test "transitioning to running causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_event(deploy)
    deploy.status = 'pending'
    deploy.run!
  end

  test "creating a deploy causes an event to be broadcasted" do
    shipit = stacks(:shipit)
    deploy = shipit.deploys.build(
      since_commit: shipit.commits.first,
      until_commit: shipit.commits.last
    )

    expect_event(deploy)
    deploy.save!
  end

  test "transitioning to success triggers next deploy when stack uses CD" do
    commits(:fifth).statuses.create!(state: 'success')

    deploy = deploys(:shipit_running)
    deploy.stack.update(continuous_deployment: true)

    assert_difference "Deploy.count" do
      deploy.complete
    end
  end

  test "transitioning to success skips CD deploy when stack doesn't use it" do
    commits(:fifth).statuses.create!(state: 'success')

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

  test "#build_rollback set the deploy until_commit as the rollback since_commit" do
    rollback = @deploy.build_rollback
    assert_equal @deploy.until_commit, rollback.since_commit
  end

  test "#build_rollback set the commit right before the deploy's since_commit as the rollback until_commit" do
    deploy = deploys(:shipit_complete)
    rollback = deploy.build_rollback
    assert_equal deploy.since_commit, rollback.until_commit
  end

  test "#build_rollback set deploy's since_commit as the rollback until_commit if it's the first one" do
    rollback = @deploy.build_rollback
    assert_equal @deploy.since_commit, rollback.until_commit
  end

  test "pid is persisted" do
    @deploy.pid = 42
    clone = Deploy.find(@deploy)
    assert_equal 42, clone.pid
  end

  test "abort! sends a SIGTERM to the recorded PID" do
    Process.expects(:kill).with('TERM', 42)
    @deploy.pid = 42
    @deploy.abort!
  end

  test "abort! still succeeds if the process is already dead" do
    Process.expects(:kill).with('TERM', 42).raises(Errno::ESRCH)
    @deploy.pid = 42
    assert_nothing_raised do
      @deploy.abort!
    end
  end

  test "abort! bails out if the PID is nil" do
    Process.expects(:kill).never
    @deploy.pid = nil
    assert_nothing_raised do
      @deploy.abort!
    end
  end

  def expect_event(deploy)
    Pubsubstub::RedisPubSub.expects(:publish).at_least_once
    Pubsubstub::RedisPubSub.expects(:publish).with do |channel, event|
      data = JSON.load(event.data)
      channel == "stack.#{deploy.stack.id}" &&
      data['url'] == "/#{deploy.stack.to_param}"
    end
  end
end
