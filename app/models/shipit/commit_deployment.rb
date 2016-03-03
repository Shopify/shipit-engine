module Shipit
  class CommitDeployment < ActiveRecord::Base
    belongs_to :commit
    belongs_to :task
    has_many :statuses, class_name: 'CommitDeploymentStatus'

    after_commit :schedule_create_on_github, on: :create

    delegate :stack, to: :task

    def create_on_github!
      return unless commit.pull_request?

      create_deployment_on_github!
      statuses.order(id: :asc).each(&:create_on_github!)
    end

    def create_deployment_on_github!
      return if github_id?

      response = Shipit.github_api.create_deployment(
        stack.github_repo_name,
        pull_request_head,
        auto_merge: false,
        description: "Via Shipit",
        environment: stack.environment,
      )
      update!(github_id: response.id, api_url: response.url)
    end

    def pull_request_head
      pull_request = Shipit.github_api.pull_request(stack.github_repo_name, commit.pull_request_number)
      pull_request.head.sha
    end

    def schedule_create_on_github
      CreateOnGithubJob.perform_later(self)
    end
  end
end
