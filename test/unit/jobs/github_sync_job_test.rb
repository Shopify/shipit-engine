require 'test_helper'

class GithubSyncJobTest < ActiveSupport::TestCase

  setup do
    @job = GithubSyncJob.new
    @stack = stacks(:shipit)
    @github_commits = stub()
    @github_repo = stub(rels: {commits: @github_commits})
  end

  test "#perform fetch commits from the API" do
    Stack.any_instance.expects(:github_repo).returns(@github_repo)
    @job.expects(:fetch_missing_commits).with(@github_commits).returns([])
    @job.perform(stack_id: @stack.id)
  end

  # TODO: test this job better

end
