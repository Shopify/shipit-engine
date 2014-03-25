class DeployCommands < Commands
  BUNDLE_WITHOUT = %w(default production development test staging benchmark debug)
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
      'USER' => @deploy.user_name,
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
end
