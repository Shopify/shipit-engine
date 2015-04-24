class GithubTeardownWebhooksJob < BackgroundJob
  queue_as :default

  extend BackgroundJob::StackExclusive

  def perform(params)
    Shipit.github_api.hooks(params[:github_repo_name]).each do |hook|
      if hook.last_response.status == 'misconfigured'
        Rails.logger.info "removing misconfigured #{hook.id}"
        Shipit.github_api.remove_hook(params[:github_repo_name], hook.id)
      else
        Rails.logger.info "everything is fine with #{hook.id}"
      end
    end

    GithubHook.where(stack_id: params[:stack_id]).each do |hook|
      begin
        Shipit.github_api.remove_hook(params[:github_repo_name], hook.github_id)
      rescue
      end
      hook.destroy
    end
  end
end
