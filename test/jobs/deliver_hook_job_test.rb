# typed: false
require 'test_helper'

module Shipit
  class DeliverHookJobTest < ActiveSupport::TestCase
    setup do
      @delivery = shipit_deliveries(:scheduled_shipit_deploy)
      @job = DeliverHookJob.new
    end

    test "#perform delivers a delivery" do
      stub_request(:post, @delivery.url).to_return(body: 'OK')
      @job.perform(@delivery)
      assert_equal 'sent', @delivery.reload.status
    end
  end
end
