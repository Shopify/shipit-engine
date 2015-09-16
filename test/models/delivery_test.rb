require 'test_helper'

class DeliveryTest < ActiveSupport::TestCase
  setup do
    @hook = hooks(:shipit_deploys)
    @delivery = @hook.deliveries.create!(event: 'deploy', status: 'scheduled', url: 'https://example.com/events/deploy',
                                         content_type: 'application/json', payload: '{"stack": {}, "deploy": {}}')
  end

  teardown do
    @hook.deliveries.destroy_all
  end

  test "#schedule! enqueue a DeliverHookJob and update the status to `scheduled`" do
    delivery = @hook.deliveries.create!(
      event: 'deploy',
      url: 'http://example.com',
      content_type: 'application/json',
      payload: '{}',
    )
    assert_equal 'pending', delivery.status

    assert_enqueued_with(job: DeliverHookJob, args: [delivery]) do
      delivery.schedule!
    end
    assert_equal 'scheduled', delivery.status
  end

  test "#send! post the payload and update the status to `sent`" do
    headers = {'content-type' => 'text/plain', 'content-length' => '2'}
    FakeWeb.register_uri(:post, @delivery.url, headers.merge(body: 'OK'))

    assert_equal 'scheduled', @delivery.status
    @delivery.send!

    assert_equal 'sent', @delivery.status
    assert_not_nil @delivery.delivered_at
    assert_equal 200, @delivery.response_code
    assert_equal headers, @delivery.response_headers
    assert_equal 'OK', @delivery.response_body
  end
end
