class DeployJob
  @queue = :deploys

  def perform(params)
    @deploy = Deploy.find(params[:deploy_id])
    @deploy.run!
    commands = StackCommands.new(@deploy.stack)

    capture commands.fetch
    capture commands.clone(@deploy)
    Dir.chdir(@deploy.working_directory) do
      capture commands.checkout(@deploy.until_commit)
      capture commands.deploy(@deploy.until_commit)
    end
    @deploy.complete!
  rescue
    @deploy.fail!
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
