class GithubSetupWebhooksJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform(params)
    stack = Stack.find(params[:stack_id])
    missing_webhooks(stack).each do |event, url|
      create_webhook(stack, event, url)
    end
  end

  private
  def create_webhook(stack, event, url)
    secret = SecureRandom.hex
    github_hook = Shipit.github_api.create_hook(stack.github_repo_name, 'web', {
      url: url,
      content_type: 'json',
      secret: secret,
    }, { events: [event], active: true })

    webhook = stack.webhooks.create!(github_id: github_hook.id, event: event, secret: secret)
  end

  def missing_webhooks(stack)
    events = Stack::REQUIRED_HOOKS - stack.webhooks.pluck(:event)
    webhook_urls(stack).slice(*events)
  end

  def webhook_urls(stack)
    url_helpers = Rails.application.routes.url_helpers
    {
      push: url_helpers.push_stack_webhooks_url(stack.id, host: host),
      status: url_helpers.state_stack_webhooks_url(stack.id, host: host),
    }.stringify_keys
  end

  def host
    Settings.host
  end
end
