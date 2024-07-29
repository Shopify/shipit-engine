# frozen_string_literal: true
# rubocop:disable Lint/MissingSuper
module Shipit
  class TaskCommands < Commands
    delegate :fetch_commit, :fetch, :fetched?, to: :stack_commands

    def initialize(task)
      @task = task
      @stack = task.stack
    end

    def deploy_spec
      @deploy_spec ||= DeploySpec::FileSystem.new(@task.working_directory, @stack)
    end

    def install_dependencies
      deploy_spec.dependencies_steps!.map do |command_line|
        Command.new(command_line, env: env, chdir: steps_directory)
      end
    end

    def perform
      steps.map do |command_line|
        Command.new(command_line, env: env, chdir: steps_directory)
      end
    end

    def steps
      @task.definition.steps
    end

    def env
      super
        .merge(@stack.env)
        .merge(
          'SHIPIT_USER' => "#{@task.author.login} (#{normalized_author_name}) via Shipit",
          'EMAIL' => @task.author.email,
          'BUNDLE_PATH' => Rails.root.join('data', 'bundler').to_s,
          'SHIPIT_LINK' => @task.permalink,
          'TASK_ID' => @task.id.to_s,
          'IGNORED_SAFETIES' => @task.ignored_safeties? ? '1' : '0',
          'GIT_COMMITTER_NAME' => @task.user&.name || Shipit.committer_name,
          'GIT_COMMITTER_EMAIL' => @task.user&.email || Shipit.committer_email,
        )
        .merge(deploy_spec.machine_env)
        .merge(@task.env)
    end

    def checkout(commit)
      git(
        '-c',
        'advice.detachedHead=false',
        'checkout',
        '--quiet',
        commit.sha,
        chdir: @task.working_directory
      )
    end

    def clone
      [
        git(
          'clone',
          '--quiet',
          '--local',
          '--origin', 'cache',
          @stack.git_path,
          @task.working_directory,
          chdir: @stack.deploys_path
        ),
        git('remote', 'add', 'origin', @stack.repo_git_url, chdir: @task.working_directory),
      ]
    end

    def stack_commands
      @stack_commands = StackCommands.new(@stack)
    end

    def clear_working_directory
      FileUtils.rm_rf(@task.working_directory) if deploy_spec.clear_working_directory?
    end

    private

    def normalized_author_name
      ActiveSupport::Inflector.transliterate(@task.author.name)
    end

    protected

    def steps_directory
      if sub_directory = deploy_spec.directory.presence
        File.join(@task.working_directory, sub_directory)
      else
        @task.working_directory
      end
    end

    private

    def github
      Shipit.github(organization: @stack.repository.owner)
    end
  end
end
