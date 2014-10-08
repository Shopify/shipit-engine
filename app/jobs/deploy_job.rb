class DeployJob < BackgroundJob
  COMMAND_TIMEOUT = 5.minutes.to_i
  @queue = :deploys

  extend BackgroundJob::StackExclusive

  def perform(params)
    @deploy = Deploy.find(params[:deploy_id])
    unless @deploy.pending?
      logger.error("Deploy ##{@deploy.id} already in `#{@deploy.status}` state. Aborting.")
      return
    end

    @deploy.run!
    commands = DeployCommands.new(@deploy)

    capture commands.fetch
    capture commands.clone
    capture commands.checkout(@deploy.until_commit)

    record_deploy_spec_abilities

    Bundler.with_clean_env do
      capture_all commands.install_dependencies
      capture_all commands.deploy(@deploy.until_commit)
    end
    @deploy.complete!
  rescue Command::Error
    @deploy.failure!
  rescue StandardError
    @deploy.error!
    raise
  ensure
    Resque.enqueue(FetchDeployedRevisionJob, stack_id: @deploy.stack_id)
    @deploy.clear_working_directory
  end

  def capture_all(commands)
    commands.map { |c| capture(c) }
  end

  def capture(command)
    command.start
    @deploy.write("$ #{command}\npid: #{command.pid}\n")
    @deploy.pid = command.pid
    command.stream!(timeout: COMMAND_TIMEOUT) do |line|
      @deploy.write(line)
    end
    @deploy.write("\n")
  end

  def record_deploy_spec_abilities
    spec = DeploySpec.new(@deploy.working_directory, @deploy.stack.environment)

    @deploy.stack.update(
      supports_rollback: spec.supports_rollback?,
      supports_fetch_deployed_revision: spec.supports_fetch_deployed_revision?
    )
  end

end
