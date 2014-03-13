class DeployJob < BackgroundJob
  @queue = :deploys

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
    Bundler.with_clean_env do
      capture commands.bundle_install
      capture commands.deploy(@deploy.until_commit)
    end
    @deploy.complete!
  rescue Command::Error
    @deploy.failure!
  rescue StandardError
    @deploy.error!
    raise
  end

  def capture(command)
    @deploy.write("$ #{command.to_s}\n")
    command.stream! do |line|
      @deploy.write(line)
    end
    @deploy.write("\n")
  end

end
