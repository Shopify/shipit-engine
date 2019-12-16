module Shipit
  class DestroyRepositoryJob < BackgroundJob
    queue_as :default

    # repository
    # +-- stacks
    #     +-- api_clients
    #     +-- commits
    #     |   +-- commit_deployments
    #     |   |   +-- statuses
    #     |   +-- statuses
    #     +-- github_hooks
    #     +-- hooks
    #     +-- pull_requests
    #     +-- tasks
    #         +-- chunks

    def perform(repository)
      repository.stacks.each { |stack| DestroyStackJob.perform_now(stack) }
      repository.destroy!
    end
  end
end
