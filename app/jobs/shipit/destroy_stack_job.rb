module Shipit
  class DestroyStackJob < BackgroundJob
    queue_as :default

    # stack
    # +-- api_clients
    # +-- commits
    # |   +-- commit_deployments
    # |   |   +-- statuses
    # |   +-- statuses
    # +-- github_hooks
    # +-- hooks
    # +-- pull_requests
    # +-- tasks
    #     +-- chunks

    def perform(stack)
      Shipit::ApiClient.where(stack_id: stack.id).delete_all
      commits_ids = Shipit::Commit.where(stack_id: stack.id).pluck(:id)
      commit_deployments_ids = Shipit::CommitDeployment.where(commit_id: commits_ids).pluck(:id)
      Shipit::CommitDeploymentStatus.where(commit_deployment_id: commit_deployments_ids).delete_all
      Shipit::CommitDeployment.where(id: commit_deployments_ids).delete_all
      Shipit::Status.where(commit_id: commits_ids).delete_all
      Shipit::Commit.where(id: commits_ids).delete_all
      Shipit::GithubHook.where(stack_id: stack.id).destroy_all
      Shipit::Hook.where(stack_id: stack.id).delete_all
      Shipit::PullRequest.where(stack_id: stack.id).delete_all
      tasks_ids = Shipit::Task.where(stack_id: stack.id).pluck(:id)
      tasks_ids.each_slice(100) do |ids|
        Shipit::OutputChunk.where(task_id: ids).delete_all
        Shipit::Task.where(id: ids).delete_all
      end
      stack.destroy!
    end
  end
end
