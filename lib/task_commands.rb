class TaskCommands < Commands
  BUNDLE_PATH = File.join(Rails.root, 'data', 'bundler')

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
      Command.new(command_line, env: env, chdir: @task.working_directory)
    end
  end

  def perform
    steps.map do |command_line|
      Command.new(command_line, env: env, chdir: @task.working_directory)
    end
  end

  def steps
    @task.definition.steps
  end

  def env
    normalized_name = ActiveSupport::Inflector.transliterate(@task.author.name)
    super.merge(
      'ENVIRONMENT' => @stack.environment,
      'USER' => "#{@task.author.login} (#{normalized_name}) via Shipit 2",
      'EMAIL' => @task.author.email,
      'BUNDLE_PATH' => BUNDLE_PATH,
      'SHIPIT_LINK' => permalink,
    ).merge(deploy_spec.machine_env)
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

  def permalink
    Rails.application.routes.url_helpers.stack_task_url(@stack, @task)
  end
end
