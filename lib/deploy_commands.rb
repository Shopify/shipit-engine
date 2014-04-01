class DeployCommands < Commands
  BUNDLE_PATH = File.join(Rails.root, "data", "bundler")

  delegate :fetch, to: :stack_commands

  def initialize(deploy)
    @deploy = deploy
    @stack = deploy.stack
  end

  def install_dependencies
    env = self.env.merge(deploy_spec.machine_env)
    deploy_spec.dependencies_steps.map do |command_line|
      Command.new(command_line, env: env, chdir: @deploy.working_directory)
    end
  end

  def deploy(commit)
    env = self.env.merge(
      'SHA' => commit.sha,
      'ENVIRONMENT' => @stack.environment,
      'USER' => "#{@deploy.user_name} via Shipit 2",
      'EMAIL' => @deploy.user_email,
    ).merge(deploy_spec.machine_env)
    deploy_spec.deploy_steps.map do |command_line|
      Command.new(command_line, env: env, chdir: @deploy.working_directory)
    end
  end

  def checkout(commit)
    git("checkout", "-q", commit.sha, chdir: @deploy.working_directory)
  end

  def clone
    git("clone", "--local", @stack.git_path, @deploy.working_directory, chdir: @stack.deploys_path)
  end

  def deploy_spec
    @deploy_spec ||= DeploySpec.new(@deploy.working_directory)
  end

  def stack_commands
    @stack_commands = StackCommands.new(@stack)
  end

  def before_deploy_steps
   deploy_spec.pre_deploy_steps
  end

  def after_deploy_steps
    steps_to_run = []

    if @deploy.status == 'success'
      steps_to_run = deploy_spec.post_success_deploy_steps + deploy_spec.post_deploy_steps
    elsif @deploy.status == 'failed'
      steps_to_run = deploy_spec.post_failure_deploy_steps + deploy_spec.post_deploy_steps
    end

    steps_to_run
  end
end
