require 'test_helper'

class GithubTeardownWebhooksJobTest < ActiveSupport::TestCase
  setup do
    @job = GithubTeardownWebhooksJob.new
    @stack = stacks(:shipit)
    @stack.remote_webhooks.destroy_all
  end

  test "#perform destroys stack webhooks" do
    Shipit.github_api.expects(:remove_hook).with('Shopify/shipit2', 13)
    Shipit.github_api.expects(:remove_hook).with('Shopify/shipit2', 23)

    @stack.remote_webhooks.create(event: 'push', github_id: 13)
    @stack.remote_webhooks.create(event: 'push', github_id: 23)

    assert_difference 'RemoteWebhook.count', -2 do
      @job.perform(stack_id: @stack.id, github_repo_name: 'Shopify/shipit2')
    end
  end
end
