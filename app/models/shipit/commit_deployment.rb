module Shipit
  class CommitDeployment < ActiveRecord::Base
    belongs_to :commit
    belongs_to :task
    has_many :statuses, dependent: :destroy, class_name: 'CommitDeploymentStatus'

    after_commit :schedule_create_on_github, on: :create

    delegate :stack, :author, to: :task

    def create_on_github!
      return unless commit.pull_request?

      create_deployment_on_github!
      statuses.order(id: :asc).each(&:create_on_github!)
    rescue Octokit::NotFound, Octokit::Forbidden
      # If no one can create the deployment we can only give up
    end

    def create_deployment_on_github!
      return if github_id?

      response = begin
        create_deployment_on_github(author.github_api)
      rescue Octokit::NotFound, Octokit::Forbidden
        raise if Shipit.github_api == author.github_api
        # If the deploy author didn't gave us the permission to create the deployment we falback the the main shipit
        # user.
        #
        # Octokit currently raise NotFound, but I'm convinced it should be Forbidden if the user can see the repository.
        # So to be future proof I catch boths.
        create_deployment_on_github(Shipit.github_api)
      end
      update!(github_id: response.id, api_url: response.url)
    end

    def pull_request_head
      pull_request = Shipit.github_api.pull_request(stack.github_repo_name, commit.pull_request_number)
      pull_request.head.sha
    end

    def schedule_create_on_github
      CreateOnGithubJob.perform_later(self)
    end

    private

    def create_deployment_on_github(client)
      client.create_deployment(
        stack.github_repo_name,
        pull_request_head,
        auto_merge: false,
        required_contexts: [],
        description: "Via Shipit",
        environment: stack.environment,
      )
    end
  end
end
