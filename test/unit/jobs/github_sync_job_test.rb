require 'test_helper'

class GithubSyncJobTest < ActiveSupport::TestCase

  setup do
    @job = GithubSyncJob.new
    @stack = stacks(:shipit)
    @github_commits = stub()
  end

  test "#perform fetch commits from the API" do
    Stack.any_instance.expects(:github_commits).returns(@github_commits)
    @job.expects(:fetch_missing_commits).with(@github_commits).returns([[], nil])
    @job.perform(stack_id: @stack.id)
  end

  test "#perform mark all childs of the common parent as detached" do
    Stack.any_instance.expects(:github_commits).returns(@github_commits)
    @job.expects(:fetch_missing_commits).with(@github_commits).returns([[], commits(:third)])

    refute commits(:fourth).reload.detached?
    refute commits(:fifth).reload.detached?

    @job.perform(stack_id: @stack.id)

    assert commits(:fourth).reload.detached?
    assert commits(:fifth).reload.detached?
  end

end
