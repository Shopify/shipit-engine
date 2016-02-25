module Shipit
  class TaskCommands < Commands
    delegate :fetch, to: :stack_commands

    def initialize(task)
      @task = task
      @stack = task.stack
    end

    def deploy_spec
      @deploy_spec ||= DeploySpec::FileSystem.new(@task.working_directory, @stack.environment)
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
      normalized_name = ActiveSupport::Inflector.transliterate(@task.author.name)
      super.merge(
        'ENVIRONMENT' => @stack.environment,
        'BRANCH' => @stack.branch,
        'USER' => "#{@task.author.login} (#{normalized_name}) via Shipit",
        'EMAIL' => @task.author.email,
        'BUNDLE_PATH' => Rails.root.join('data', 'bundler').to_s,
        'SHIPIT_LINK' => permalink,
        'LAST_DEPLOYED_SHA' => @stack.last_deployed_commit.sha,
      ).merge(deploy_spec.machine_env).merge(@task.env)
    end

    def checkout(commit)
      git('checkout', commit.sha, chdir: @task.working_directory)
    end

    def clone
      git('clone', '--local', @stack.git_path, @task.working_directory, chdir: @stack.deploys_path)
    end

    def stack_commands
      @stack_commands = StackCommands.new(@stack)
    end

    protected

    def steps_directory
      if sub_directory = deploy_spec.directory.presence
        File.join(@task.working_directory, sub_directory)
      else
        @task.working_directory
      end
    end

    def permalink
      Shipit::Engine.routes.url_helpers.stack_task_url(@stack, @task)
    end
  end
end
