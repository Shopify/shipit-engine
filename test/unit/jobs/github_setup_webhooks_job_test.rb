require 'test_helper'

class GithubSetupWebhooksJobTest < ActiveSupport::TestCase
  setup do
    @job = GithubSetupWebhooksJob.new
    @stack = stacks(:shipit)

    SecureRandom.stubs(:hex).returns('1234')
  end

  test "#perform calls GithubTeardownWebhooksJob" do
    GithubTeardownWebhooksJob.any_instance.expects(:perform).with(has_entry(:stack_id, @stack.id))

    Shipit.github_api.expects(:create_hook).at_least(0).returns(stub(id: 121))
    @job.perform(stack_id: @stack.id, hostname: "example.com")
  end

  test "#perform creates webhooks for push and status" do
    @stack.webhooks.destroy_all

    Shipit.github_api.expects(:hooks).with('shopify/shipit2').returns([])

    Shipit.github_api.expects(:create_hook).with('shopify/shipit2', 'web', {
      url: "https://example.com/stacks/#{@stack.id}/webhooks/push",
      content_type: 'json',
      secret: '1234',
    }, { events: ['push'], active: true }).returns(stub(id: 122))

    Shipit.github_api.expects(:create_hook).with('shopify/shipit2', 'web', {
      url: "https://example.com/stacks/#{@stack.id}/webhooks/state",
      content_type: 'json',
      secret: '1234',
    }, { events: ['status'], active: true }).returns(stub(id: 123))

    assert_difference 'Webhook.count', +2 do
      @job.perform(stack_id: @stack.id, hostname: "example.com")
    end

    assert_equal Stack::REQUIRED_HOOKS.map(&:to_s), @stack.webhooks.pluck(:event).sort
  end
end
