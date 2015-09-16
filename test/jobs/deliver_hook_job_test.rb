require 'test_helper'

class DeliverHookJobTest < ActiveSupport::TestCase
  setup do
    @delivery = hooks(:shipit_deploys).deliveries.create!(event: 'deploy', status: 'scheduled',
                                                          url: 'https://example.com/events/deploy',
                                                          content_type: 'application/json',
                                                          payload: '{"stack": {}, "deploy": {}}')
    @job = DeliverHookJob.new
  end

  teardown do
    hooks(:shipit_deploys).deliveries.destroy_all
  end

  test "#perform delivers a delivery" do
    FakeWeb.register_uri(:post, @delivery.url, body: 'OK')
    @job.perform(@delivery)
    assert_equal 'sent', @delivery.reload.status
  end
end
