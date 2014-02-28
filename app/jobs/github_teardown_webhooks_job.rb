class GithubTeardownWebhooksJob < BackgroundJob
  extend Resque::Plugins::Lock

  @queue = :default

  def perform(params)
    Webhook.where(stack_id: params[:stack_id]).each do |webhook|
      Shipit.github_api.remove_hook(params[:github_repo_name], webhook.github_id)
      webhook.destroy
    end
  end
end
