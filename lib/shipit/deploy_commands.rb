# frozen_string_literal: true

module Shipit
  class DeployCommands < TaskCommands
    def initialize(task)
      super
      @failed = false
      @error_message = nil
    end

    def steps
      deploy_spec.deploy_steps!
    end

    def failure_step
      return unless deploy_spec.deploy_post.present?

      command = Command.new(deploy_spec.deploy_post, env:, chdir: steps_directory)
      command if command.run_on_error
    end

    def failed!(error_message = nil)
      @failed = true
      @error_message = error_message
    end

    def env
      commit = @task.until_commit
      super.merge(
        'SHA' => commit.sha,
        'REVISION' => commit.sha,
        'DIFF_LINK' => diff_url,
        'FAILED' => @failed ? '1' : '0',
        'FAILURE_MESSAGE' => @error_message.to_s
      )
    end

    protected

    def diff_url
      Shipit::GithubUrlHelper.github_commit_range_url(@stack, *@task.commit_range)
    end
  end
end
