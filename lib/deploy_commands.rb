class DeployCommands < TaskCommands

  def steps
    deploy_spec.deploy_steps!
  end

  def env
    commit = @task.until_commit
    super.merge(
      'SHA' => commit.sha,
      'REVISION' => commit.sha,
    )
  end

end
