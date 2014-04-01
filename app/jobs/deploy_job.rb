class DeployJob < BackgroundJob
  @queue = :deploys

  extend BackgroundJob::StackExclusive

  def perform(params)
    @deploy = Deploy.find(params[:deploy_id])
    unless @deploy.pending?
      logger.error("Deploy ##{@deploy.id} already in `#{@deploy.status}` state. Aborting.")
      return
    end

    @deploy.run!
    begin
      capture commands.fetch
      capture commands.clone
      capture commands.checkout(@deploy.until_commit)
      Bundler.with_clean_env do
        capture_all commands.install_dependencies
        capture_all commands.deploy(@deploy.until_commit)
      end
    rescue Command::Error => e
      @deploy.failure!
      capture_all commands.failure_hooks(e.message)
    else
      @deploy.complete!
      capture_all commands.success_hooks
    end

  rescue StandardError => e
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

end
