class GithubDeployStatusJob < BackgroundJob
  @queue = :default

  include BackgroundJob::DeployExclusive

  def perform(params)
    deploy = Deploy.find(params[:deploy_id])
    deploy.push_github_status(params[:status])
  end

end
