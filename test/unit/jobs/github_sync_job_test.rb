require 'test_helper'

class GithubSyncJobTest < ActiveSupport::TestCase

  setup do
    @job = GithubSyncJob.new
    @stack = stacks(:shipit)
    @github_commits = stub()
  end

  test "#perform fetch commits from the API" do
    Stack.any_instance.expects(:github_commits).returns(@github_commits)
    @job.expects(:fetch_missing_commits).with(@github_commits).returns([])
    @job.perform(stack_id: @stack.id)
  end

  # TODO: test this job better

end
