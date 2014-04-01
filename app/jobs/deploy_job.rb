class DeployJob < BackgroundJob
  @queue = :deploys

  extend BackgroundJob::StackExclusive

  def perform(params)
    @deploy = Deploy.find(params[:deploy_id])
    unless @deploy.pending?
      logger.error("Deploy ##{@deploy.id} already in `#{@deploy.status}` state. Aborting.")
      return
    end

    pre_deploy_steps
    @deploy.run!

    capture commands.fetch
    capture commands.clone
    capture commands.checkout(@deploy.until_commit)
    Bundler.with_clean_env do
      capture_all commands.install_dependencies
      capture_all commands.deploy(@deploy.until_commit)
    end
    post_deploy_steps
    @deploy.complete!
  rescue Command::Error
    post_deploy_steps
    @deploy.failure!
  rescue StandardError
    @deploy.error!
    raise
  end

  def commands
    @deploy_commands ||= DeployCommands.new(@deploy)
  end

  def capture_all(deploy_commands)
    deploy_commands.map { |c| capture(c) }
  end

  def capture(command)
    @deploy.write("$ #{command.to_s}\n")
    command.stream! do |line|
      @deploy.write(line)
    end
    @deploy.write("\n")
  end

  def pre_deploy_steps
    commands.before_deploy_steps.map do |command_line|
      Command.new(command_line, env: env, chdir: @deploy.working_directory)
    end
  end

  def post_deploy_steps
    commands.after_deploy_steps.map do |command_line|
      Command.new(command_line, env: env, chdir: @deploy.working_directory)
    end
  end

end
