class GithubSetupWebhooksJob < BackgroundJob
  @queue = :default

  def perform(params)
    stack = Stack.find(params[:stack_id])
    missing_webhooks(stack).each do |event, url|
      create_webhook(stack, event, url)
    end
  end

  private
  def create_webhook(stack, event, url)
    github_hook = Shipit.github_api.create_hook(stack.github_repo_name, 'web', {
      url: url,
      content_type: 'json'
    }, { events: [event], active: true })

    webhook = stack.webhooks.create!(github_id: github_hook.id, event: event)
  end

  def missing_webhooks(stack)
    events = Stack::REQUIRED_HOOKS - stack.webhooks.pluck(:event)
    webhook_urls(stack).slice(*events)
  end

  def webhook_urls(stack)
    url_helpers = Rails.application.routes.url_helpers
    {
      push: url_helpers.push_stack_webhooks_url(stack, host: host),
      state: url_helpers.state_stack_webhooks_url(stack, host: host),
    }.stringify_keys
  end

  def host
    Settings.host
  end
end
