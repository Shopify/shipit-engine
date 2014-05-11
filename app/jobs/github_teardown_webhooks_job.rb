class GithubTeardownWebhooksJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform(params)
    RemoteWebhook.where(stack_id: params[:stack_id]).each do |remote_webhook|
      Shipit.github_api.remove_hook(params[:github_repo_name], remote_webhook.github_id)
      remote_webhook.destroy
    end
  end
end
