class GithubTeardownWebhooksJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform(params)
    Webhook.where(stack_id: params[:stack_id]).each do |webhook|
      begin
        Shipit.github_api.remove_hook(params[:github_repo_name], webhook.github_id)
      rescue
      end
      webhook.destroy
    end
  end
end
