module Shipit
  class CommitDeploymentStatus < ActiveRecord::Base
    belongs_to :commit_deployment

    after_commit :schedule_create_on_github, on: :create

    delegate :stack, :task, to: :commit_deployment

    def create_on_github!
      return if github_id?
      response = Shipit.github_api.create_deployment_status(
        commit_deployment.api_url,
        status,
        target_url: url_helpers.stack_deploy_url(stack, task),
        description: description,
      )
      update!(github_id: response.id, api_url: response.url)
    end

    def description
      I18n.t(
        "deployment_description.#{task_type}.#{status}",
        sha: task.until_commit.sha,
        author: task.author.login,
        stack: stack.to_param,
      )
    end

    def task_type
      task.class.name.demodulize.underscore
    end

    def schedule_create_on_github
      CreateOnGithubJob.perform_later(commit_deployment)
    end

    private

    def url_helpers
      Engine.routes.url_helpers
    end
  end
end
