# frozen_string_literal: true
module Shipit
  class CommitDeployment < Record
    belongs_to :task
    has_many :statuses, dependent: :destroy, class_name: 'CommitDeploymentStatus'

    after_commit :schedule_create_on_github, on: :create

    delegate :stack, :author, to: :task

    def create_on_github!
      create_deployment_on_github!
      statuses.order(id: :asc).each { |status| CreateOnGithubJob.perform_later(status) }
    rescue Octokit::NotFound, Octokit::Forbidden => error
      Rails.logger.warn("Got #{error.class.name} creating deployment or statuses: #{error.message}")
      # If no one can create the deployment we can only give up
    end

    def create_deployment_on_github!
      return if github_id?

      response = begin
        create_deployment_on_github(stack.github_api)
      rescue Octokit::ClientError
        raise if Shipit.github(organization: stack.repository.owner).api == stack.github_api
        # If the deploy author didn't gave us the permission to create the deployment we falback the the main shipit
        # user.
        #
        # Octokit currently raise NotFound, but I'm convinced it should be Forbidden if the user can see the repository.
        # So to be future proof I catch boths.
        create_deployment_on_github(stack.github_api)
      end
      update!(github_id: response.id, api_url: response.url)
    end

    def schedule_create_on_github
      CreateOnGithubJob.perform_later(self)
    end

    def short_sha
      sha[0..9]
    end

    private

    def create_deployment_on_github(client)
      client.create_deployment(
        stack.github_repo_name,
        sha,
        auto_merge: false,
        required_contexts: [],
        description: "Via #{Shipit.app_name}",
        environment: stack.environment,
        payload: {
          shipit: {
            task_id: task.id,
            from_sha: task.since_commit.sha,
            to_sha: task.until_commit.sha,
          },
        }.to_json,
      )
    end
  end
end
