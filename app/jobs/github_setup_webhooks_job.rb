class GithubSetupWebhooksJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform
    GithubTeardownWebhooksJob.new(stack_id: stack.id, github_repo_name: stack.github_repo_name).perform

    webhook_urls.slice(*Stack::REQUIRED_HOOKS).each do |event, url|
      create_webhook(event, url)
    end
  end

  private

  def create_webhook(event, url)
    secret = SecureRandom.hex
    github_hook = Shipit.github_api.create_hook(stack.github_repo_name, 'web', {
      url: url,
      content_type: 'json',
      secret: secret,
    }, { events: [event.to_s], active: true })

    stack.webhooks.create!(github_id: github_hook.id, event: event, secret: secret)
  end

  def webhook_urls
    url_helpers = Rails.application.routes.url_helpers
    {
      push: url_helpers.push_stack_webhooks_url(stack.id, host: host),
      status: url_helpers.state_stack_webhooks_url(stack.id, host: host),
    }
  end

  def host
    Shipit.host
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end
end
