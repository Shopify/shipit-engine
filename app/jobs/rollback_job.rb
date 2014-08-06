class RollbackJob < BackgroundJob
  COMMAND_TIMEOUT = 5.minutes.to_i
  @queue = :deploys

  extend BackgroundJob::StackExclusive

  def perform(params)
    @deploy = Deploy.find(params[:deploy_id])
    unless @deploy.complete?
      logger.error("Deploy ##{@deploy.id} has not completed `#{@deploy.status}`. Aborting.")
      return
    end

    commands = DeployCommands.new(@deploy)

    capture commands.fetch
    capture commands.clone
    capture commands.checkout(@deploy.until_commit)
    Bundler.with_clean_env do
      capture_all commands.install_dependencies
      capture_all commands.rollback(@deploy.until_commit)
    end
    @deploy.rollback!
  rescue Command::Error
    @deploy.failure!
  rescue StandardError
    @deploy.error!
    raise
  ensure
    @deploy.clear_working_directory
  end

  def capture_all(commands)
    commands.map { |c| capture(c) }
  end

  def capture(command)
    @deploy.write("$ #{command.to_s}\n")
    command.stream!(timeout: COMMAND_TIMEOUT) do |line|
      @deploy.write(line)
    end
    @deploy.write("\n")
  end

end
