# frozen_string_literal: true
# rubocop:disable Lint/MissingSuper
require 'pathname'
require 'fileutils'

module Shipit
  class PredictiveBranchTaskCommands < TaskCommands

    SPEC_TTL = 60.minutes

    def initialize(task)
      @task = task
      @stack = task.stack
    end

    def steps
      # stack_spec.ci_stack_step(@task.type)
      deploy_spec.ci_stack_step(@task.predictive_task_type)
    end

    def env
      super.merge(
        'BRANCH' => @task.predictive_branch.branch,
        'PREDICTIVE_BUILD_ID' => @task.predictive_branch.id.to_s,
      )
    end

    def stack_spec
      Rails.cache.fetch(@stack.id.to_s + ':' + @task.predictive_branch.branch, expires_in: SPEC_TTL) do
        return deploy_spec
      end
    end

    def perform
      steps.map do |command_line|
        Command.new(command_line, env: env, chdir: steps_directory)
      end
    end

    def fetch(predictive_branch)
      if Dir.exist?(@task.working_directory)
        git('fetch', 'origin', '--tags', predictive_branch.branch, env: env, chdir: @task.working_directory).run!
        checkout(nil).run!
      else
        create_directories
        git('clone', '--recursive', '--branch', predictive_branch.branch, @stack.repo_git_url, '.', chdir: @task.working_directory, env: env).run!
      end
    end

    def create_directories
      FileUtils.mkdir_p(@task.working_directory)
    end

    def install_dependencies
      []
    end

    def checkout(commit)
      git('checkout', '-b', @task.predictive_branch.branch, chdir: @task.working_directory)
    end

    protected

=begin
    TODO:
    def diff_url
      Shipit::GithubUrlHelper.github_commit_range_url(@stack, *@task.commit_range)
    end
=end
  end
end
