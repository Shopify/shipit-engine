class DeployJob

  def perform(params)
    deploy = Deploy.find(params[:deploy_id])
    commands = StackCommands.new(deploy.stack)

    commands.fetch
    commands.clone(deploy)
    Dir.chdir(deploy.working_directory) do
      commands.checkout(deploy.until_commit)
      commands.deploy(deploy.until_commit)
    end
  end

end
