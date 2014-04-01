class DeployCommands < Commands
  BUNDLE_PATH = File.join(Rails.root, "data", "bundler")

  delegate :fetch, to: :stack_commands

  def initialize(deploy)
    @deploy = deploy
    @stack = deploy.stack
  end

  def install_dependencies
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
    )
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

  def before_deploy_steps(deploy)
    pre_steps = deploy_spec.pre_deploy_steps

    pre_steps.map do |command_line|
      Command.new(command_line, env: env, chdir: deploy.working_directory)
    end
  end

  def after_deploy_steps(deploy)
    post_steps = deploy_spec.post_deploy_steps

    if deploy.complete!
      steps_to_run = post_steps.on_success + post_steps.after_deploy
    elsif deploy.failure! || deploy.error!
      steps_to_run = post_steps.on_failure + post_steps.after_deploy
    end

    steps_to_run.map do |command_line|
      Command.new(command_line, env: env, chdir: deploy.working_directory)
    end
  end

end
