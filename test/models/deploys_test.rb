require 'test_helper'

class DeploysTest < ActiveSupport::TestCase
  def setup
    @deploy = deploys(:shipit)
    @deploy.pid = 42
    @stack = stacks(:shipit)
    @user = users(:walrus)
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
    stack = stacks(:shipit)
    deploy = stack.deploys.new
    last = stack.deploys.success.last.until_commit_id
    assert_equal last, deploy.since_commit_id
  end

  test "#commits returns empty array if stack isn't set" do
    @deploy.expects(:stack).returns(nil)
    assert_equal [], @deploy.commits
  end

  test "additions and deletions are denormalized on before create" do
    stack = stacks(:shipit)
    first = commits(:first)
    third = commits(:third)

    deploy = stack.deploys.create!(
      since_commit: first,
      until_commit: third,
    )

    assert_equal 13, deploy.additions
    assert_equal 65, deploy.deletions
  end

  test "#commits returns the commits in the id range" do
    stack = stacks(:shipit)
    first = commits(:first)
    last = commits(:third)

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
    stack = stacks(:shipit)
    first = commits(:first)
    last = commits(:fourth)

    deploy = stack.deploys.new(
      since_commit: first,
      until_commit: last,
    )

    assert_equal [4, 3, 2], deploy.commits.pluck(:id)
  end

  test "transitioning to success causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_hook(:deploy, deploy.stack, status: 'success', deploy: deploy, stack: deploy.stack)
    expect_event(deploy)
    deploy.status = 'running'
    deploy.complete!
  end

  test "transitioning to failed causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_hook(:deploy, deploy.stack, status: 'failed', deploy: deploy, stack: deploy.stack)
    expect_event(deploy)
    deploy.status = 'running'
    deploy.failure!
  end

  test "transitioning to error causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_hook(:deploy, deploy.stack, status: 'error', deploy: deploy, stack: deploy.stack)
    expect_event(deploy)
    deploy.status = 'running'
    deploy.error!
  end

  test "transitioning to running causes an event to be broadcasted" do
    deploy = deploys(:shipit_pending)

    expect_hook(:deploy, deploy.stack, status: 'running', deploy: deploy, stack: deploy.stack)
    expect_event(deploy)
    deploy.status = 'pending'
    deploy.run!
  end

  test "creating a deploy causes an event to be broadcasted" do
    shipit = stacks(:shipit)
    deploy = shipit.deploys.build(
      since_commit: shipit.commits.first,
      until_commit: shipit.commits.last,
    )

    expect_event(deploy)
    deploy.save!
  end

  test "transitioning to success triggers next deploy when stack uses CD" do
    commits(:fifth).statuses.create!(state: 'success')

    deploy = deploys(:shipit_running)
    deploy.stack.update(continuous_deployment: true)

    assert_difference "Deploy.count" do
      deploy.complete!
    end
  end

  test "transitioning to success skips CD deploy when stack doesn't use it" do
    commits(:fifth).statuses.create!(state: 'success')

    deploy = deploys(:shipit_running)

    assert_no_difference "Deploy.count" do
      deploy.complete!
    end
  end

  test "transitioning to success skips CD when no successful commits after until_commit" do
    deploy = deploys(:shipit_running)
    deploy.stack.update(continuous_deployment: true)

    assert_no_difference "Deploy.count" do
      deploy.complete!
    end
  end

  test "transitioning to success schedule a fetch of the deployed revision" do
    @deploy = deploys(:shipit_running)
    assert_enqueued_with(job: FetchDeployedRevisionJob, args: [@deploy.stack]) do
      @deploy.complete!
    end
  end

  test "transitioning to failure schedule a fetch of the deployed revision" do
    @deploy = deploys(:shipit_running)
    assert_enqueued_with(job: FetchDeployedRevisionJob, args: [@deploy.stack]) do
      @deploy.failure!
    end
  end

  test "transitioning to error schedule a fetch of the deployed revision" do
    @deploy = deploys(:shipit_running)
    assert_enqueued_with(job: FetchDeployedRevisionJob, args: [@deploy.stack]) do
      @deploy.error!
    end
  end

  test "transitioning to aborted schedule a rollback if required" do
    @deploy = deploys(:shipit_running)
    @deploy.pid = 42
    @deploy.abort!(rollback_once_aborted: true)

    assert_difference -> { @stack.rollbacks.count }, 1 do
      assert_enqueued_with(job: PerformTaskJob) do
        @deploy.aborted!
      end
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
    assert_equal commits(:fourth), @stack.last_deployed_commit
    rollback = @deploy.trigger_rollback
    rollback.run!
    rollback.complete!
    assert_equal commits(:second), @stack.last_deployed_commit
  end

  test "#trigger_revert rolls the stack back to before this deploy" do
    assert_equal commits(:fourth), @stack.last_deployed_commit
    rollback = @deploy.trigger_revert
    rollback.run!
    rollback.complete!
    assert_equal commits(:first), @stack.last_deployed_commit
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

  test "pid is persisted" do
    clone = Deploy.find(@deploy.id)
    assert_equal 42, clone.pid
  end

  test "abort! transition to `aborting`" do
    @deploy.abort!
    assert_equal 'aborting', @deploy.status
  end

  test "abort! schedule the rollback if `rollback_once_aborted` is true" do
    @deploy.abort!(rollback_once_aborted: true)
    assert @deploy.reload.rollback_once_aborted?
  end

  test "abort! sends a SIGTERM to the recorded PID" do
    Process.expects(:kill).with('TERM', @deploy.pid)
    @deploy.abort!
  end

  test "abort! still succeeds if the process is already dead" do
    Process.expects(:kill).with('TERM', @deploy.pid).raises(Errno::ESRCH)
    assert_nothing_raised do
      @deploy.abort!
    end
  end

  test "abort! transition to `aborted` if the process is already dead" do
    @deploy = deploys(:shipit_running)
    @deploy.pid = 42

    @deploy.abort!
    assert_equal 'aborting', @deploy.status

    Process.expects(:kill).with('TERM', @deploy.pid).raises(Errno::ESRCH)
    @deploy.abort!
    assert_equal 'aborted', @deploy.status
  end

  test "abort! bails out if the PID is nil" do
    Process.expects(:kill).never
    @deploy.pid = nil
    assert_nothing_raised do
      @deploy.abort!
    end
  end

  test "destroy deletes the related output chunks" do
    assert_difference -> { @deploy.chunks.count }, -@deploy.chunks.count do
      @deploy.destroy
    end
  end

  test "#chunk_output joins all chunk test if logs not rolled up" do
    assert_equal @deploy.chunks.count, @deploy.chunks.count
    assert_equal @deploy.chunks.pluck(:text).join, @deploy.chunk_output
    refute @deploy.rolled_up
  end

  test "#chunk_output returns logs from records if rolled up" do
    expected_output = @deploy.chunks.pluck(:text).join
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
    @deploy = deploys(:shipit2)
    assert_predicate @deploy, :failed?

    (Deploy::CONFIRMATIONS_REQUIRED - 1).times do
      @deploy.accept!
      assert_predicate @deploy, :flapping?
    end

    @deploy.accept!
    assert_predicate @deploy, :success?
  end

  test "#reject! bails out if the deploy is failed already" do
    @deploy = deploys(:shipit2)
    assert_predicate @deploy, :failed?

    Deploy::CONFIRMATIONS_REQUIRED.times do
      @deploy.reject!
      assert_predicate @deploy, :failed?
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

  private

  def expect_event(deploy)
    Pubsubstub::RedisPubSub.expects(:publish).at_least_once
    Pubsubstub::RedisPubSub.expects(:publish).with do |channel, event|
      data = JSON.load(event.data)
      channel == "stack.#{deploy.stack.id}" && data['url'] == "/#{deploy.stack.to_param}"
    end
  end

  def expect_hook(event, stack, payload)
    Hook.expects(:emit).with(event, stack, payload)
  end
end
