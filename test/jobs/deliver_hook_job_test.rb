require 'test_helper'

class DeliverHookJobTest < ActiveSupport::TestCase
  setup do
    @delivery = deliveries(:scheduled_shipit_deploy)
    @job = DeliverHookJob.new
  end

  test "#perform delivers a delivery" do
    FakeWeb.register_uri(:post, @delivery.url, body: 'OK')
    @job.perform(delivery_id: @delivery.id)
    assert_equal 'sent', @delivery.reload.status
  end
end
