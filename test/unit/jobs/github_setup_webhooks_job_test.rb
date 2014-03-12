require 'test_helper'

class GithubSetupWebhooksJobTest < ActiveSupport::TestCase
  setup do
    @job = GithubSetupWebhooksJob.new
    @stack = stacks(:shipit)
  end

  test "#perform creates webhooks for push and status" do
    Shipit.github_api.expects(:create_hook).with('shopify/shipit2', 'web', {
      url: "https://example.com/stacks/#{@stack.id}/webhooks/push",
      content_type: 'json'
    }, { events: ['push'], active: true }).returns(stub(id: 122))

    Shipit.github_api.expects(:create_hook).with('shopify/shipit2', 'web', {
      url: "https://example.com/stacks/#{@stack.id}/webhooks/state",
      content_type: 'json'
    }, { events: ['status'], active: true }).returns(stub(id: 123))

    assert_difference 'Webhook.count', +2 do
      @job.perform(stack_id: @stack.id, hostname: "example.com")
    end

    assert_equal Stack::REQUIRED_HOOKS, @stack.webhooks.pluck(:event).sort
  end

  test "#perform creates only missing webhooks" do
    @stack.webhooks.create(event: 'status', github_id: 1)

    Shipit.github_api.expects(:create_hook).with('shopify/shipit2', 'web', {
      url: "https://example.com/stacks/#{@stack.id}/webhooks/push",
      content_type: 'json'
    }, { events: ['push'], active: true }).returns(stub(id: 122))

    assert_difference 'Webhook.count', +1 do
      @job.perform(stack_id: @stack.id, hostname: "example.com")
    end

    assert_equal Stack::REQUIRED_HOOKS, @stack.webhooks.pluck(:event).sort
  end
end
