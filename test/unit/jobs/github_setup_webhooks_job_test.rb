require 'test_helper'

class GithubSetupWebhooksJobTest < ActiveSupport::TestCase
  setup do
    @job = GithubSetupWebhooksJob.new
    @stack = stacks(:shipit)

    SecureRandom.stubs(:hex).returns('1234')
  end

  test "#perform creates webhooks for push and status" do
    @stack.remote_webhooks.destroy_all

    Shipit.github_api.expects(:create_hook).with('shopify/shipit2', 'web', {
      url: "https://example.com/stacks/#{@stack.id}/remote_webhooks/push",
      content_type: 'json',
      secret: '1234',
    }, { events: ['push'], active: true }).returns(stub(id: 122))

    Shipit.github_api.expects(:create_hook).with('shopify/shipit2', 'web', {
      url: "https://example.com/stacks/#{@stack.id}/remote_webhooks/state",
      content_type: 'json',
      secret: '1234',
    }, { events: ['status'], active: true }).returns(stub(id: 123))

    assert_difference 'RemoteWebhook.count', +2 do
      @job.perform(stack_id: @stack.id, hostname: "example.com")
    end

    assert_equal Stack::REQUIRED_HOOKS, @stack.remote_webhooks.pluck(:event).sort
  end

  test "#perform creates only missing webhooks" do
    @stack.remote_webhooks.where(event: 'push').destroy_all

    Shipit.github_api.expects(:create_hook).with('shopify/shipit2', 'web', {
      url: "https://example.com/stacks/#{@stack.id}/remote_webhooks/push",
      content_type: 'json',
      secret: '1234',
    }, { events: ['push'], active: true }).returns(stub(id: 122))

    assert_difference 'RemoteWebhook.count', +1 do
      @job.perform(stack_id: @stack.id, hostname: "example.com")
    end

    assert_equal Stack::REQUIRED_HOOKS, @stack.remote_webhooks.pluck(:event).sort
  end
end
