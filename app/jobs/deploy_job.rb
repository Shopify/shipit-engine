class DeployJob
  @queue = :deploys

  def perform(params)
    @deploy = Deploy.find(params[:deploy_id])
    @deploy.started!

    commands = StackCommands.new(@deploy.stack)

    capture commands.fetch
    capture commands.clone(@deploy)
    Dir.chdir(@deploy.working_directory) do
      capture commands.checkout(@deploy.until_commit)
      capture commands.deploy(@deploy.until_commit)
    end
  rescue
    @deploy.failed! if @deploy
    raise
  end

  def capture(command)
    @deploy.write("$ #{command.to_s}\n")
    command.stream do |line|
      @deploy.write(line)
    end
    @deploy.write("\n")
  end
end
