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
      delete(Shipit::ApiClient.where(stack_id: stack.id))

      delete(
        Shipit::CommitDeploymentStatus
        .joins(commit_deployment: [:task])
        .where(commit_deployment: { tasks: { stack_id: stack.id } })
      )

      delete(Shipit::CommitDeployment.joins(:task).where(task: { stack_id: stack.id }))
      delete(Shipit::Status.joins(:commit).where(commit: { stack_id: stack.id }))
      delete(Shipit::GithubHook.where(stack_id: stack.id))
      delete(Shipit::Hook.where(stack_id: stack.id))
      delete(Shipit::MergeRequest.where(stack_id: stack.id))

      delete(Shipit::OutputChunk.joins(:task).where(task: { stack_id: stack.id }))
      delete(Shipit::Task.where(stack_id: stack.id))

      delete(Shipit::Commit.where(stack_id: stack.id))

      stack.destroy!
    end

    private

    BATCH_SIZE = 1000

    def delete(relation)
      if relation.connection.adapter_name.match?(/(mysql|trilogy)/i)
        while relation.limit(BATCH_SIZE).delete_all == BATCH_SIZE
          true # loop
        end
      else
        while relation.model.where(id: relation.select(:id).limit(BATCH_SIZE)).delete_all == BATCH_SIZE
          true # loop
        end
      end
    end
  end
end
