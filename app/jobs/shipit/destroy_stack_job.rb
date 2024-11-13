# frozen_string_literal: true
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
    # +-- merge_requests
    # +-- tasks
    #     +-- chunks

    def perform(stack)
      Shipit::ApiClient.where(stack_id: stack.id).delete_all
      commits_ids = Shipit::Commit.where(stack_id: stack.id).pluck(:id)
      tasks_ids = Shipit::Task.where(stack_id: stack.id).pluck(:id)
      commit_deployments_ids = Shipit::CommitDeployment.where(task_id: tasks_ids).pluck(:id)
      Shipit::CommitDeploymentStatus.where(commit_deployment_id: commit_deployments_ids).in_batches(&:delete_all)
      Shipit::CommitDeployment.where(id: commit_deployments_ids).in_batches(&:delete_all)

      commits_ids.each_slice(1000) do |commit_ids_batch|
        Shipit::Status.where(commit_id: commit_ids_batch)
          .in_batches(of: 500)
          .delete_all
      end

      commits_ids.each_slice(1000) do |batch|
        Shipit::Commit.where(id: batch).delete_all
      end

      Shipit::GithubHook.where(stack_id: stack.id).destroy_all
      Shipit::Hook.where(stack_id: stack.id).in_batches(&:delete_all)
      Shipit::MergeRequest.where(stack_id: stack.id).in_batches(&:delete_all)
      tasks_ids.each_slice(100) do |ids|
        Shipit::OutputChunk.where(task_id: ids).in_batches(&:delete_all)
        Shipit::Task.where(id: ids).in_batches(&:delete_all)
      end
      stack.destroy!
    end
  end
end
