class RemoteWebhookJob < BackgroundJob
  @queue = :remote_webhooks

  def perform(params)
    if params[:deploy_id]
      @deploy = Deploy.find(params[:deploy_id])
      call_deploy_webhooks(@deploy)
    elsif params[:commit_id]
      @commit = Commit.find(params[:commit_id])
      call_commits_webhooks(@commit)
    end
  end

  def call_deploy_webhooks(deploy)
    deploy.stack.remote_webhooks.each do |e|
     e POST deploy.repo_name, repo_owner l... status
    end
  end

  def call_commit_webhooks(deploy)

  end
end
