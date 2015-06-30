require 'test_helper'

class GithubSyncJobTest < ActiveSupport::TestCase
  setup do
    @job = GithubSyncJob.new
    @stack = stacks(:shipit)
    @github_commits = stub
  end

  test "#perform fetch commits from the API" do
    Stack.any_instance.expects(:github_commits).returns(@github_commits)
    @job.expects(:fetch_missing_commits).yields.returns([[], nil])
    @job.perform(stack_id: @stack.id)
  end

  test "#perform finally enqueue a CacheDeploySpecJob" do
    Stack.any_instance.stubs(:github_commits).returns(@github_commits)
    @job.stubs(:fetch_missing_commits).yields.returns([[], nil])

    assert_enqueued_with(job: CacheDeploySpecJob, args: [@stack]) do
      @job.perform(stack_id: @stack.id)
    end
  end

  test "#perform mark all childs of the common parent as detached" do
    Stack.any_instance.expects(:github_commits).returns(@github_commits)
    @job.expects(:fetch_missing_commits).yields.returns([[], commits(:third)])

    refute commits(:fourth).reload.detached?
    refute commits(:fifth).reload.detached?

    @job.perform(stack_id: @stack.id)

    assert commits(:fourth).reload.detached?
    assert commits(:fifth).reload.detached?
  end

  test "#fetch_missing_commits returns the commits in the reverse order if it doesn't know the parent" do
    last = stub(sha: 123)
    first = stub(sha: 345)
    Shipit::FirstParentCommitsIterator.any_instance.stubs(:each).multiple_yields(last, first)
    @job.stubs(lookup_commit: nil)

    commits, parent = @job.fetch_missing_commits { stub }
    assert_nil parent
    assert_equal [first, last], commits
  end

  test "#fetch_missing_commits returns the commits in the reverse order if it knows the parent" do
    last = stub(sha: 123)
    first = stub(sha: 345)
    Shipit::FirstParentCommitsIterator.any_instance.stubs(:each).multiple_yields(last, first)
    @job.stubs(:lookup_commit).with(123).returns(nil)
    @job.stubs(:lookup_commit).with(345).returns(first)

    commits, parent = @job.fetch_missing_commits { stub }
    assert_equal first, parent
    assert_equal [last], commits
  end

  test "if GitHub returns a 404, the stacks is marked as inaccessible" do
    @job.expects(:fetch_missing_commits).raises(Octokit::NotFound)
    @job.perform(stack_id: @stack.id)

    assert_equal true, @stack.reload.inaccessible_since?
  end
end
