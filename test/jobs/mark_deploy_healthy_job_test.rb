# frozen_string_literal: true

require 'test_helper'

module Shipit
  class MarkDeployHealthyJobTest < ActiveSupport::TestCase
    setup do
      @job = MarkDeployHealthyJob.new
      @deploy = shipit_deploys(:canaries_validating)
    end

    test "#perform bails out if the deploy was marked as healthy or faulty" do
      @deploy.report_faulty!
      assert_no_difference -> { ReleaseStatus.count } do
        @job.perform(@deploy)
      end
    end

    test "#perform appends the new status if no other status was appended in the meantime" do
      assert_difference -> { ReleaseStatus.count }, +1 do
        @job.perform(@deploy)
      end
    end
  end
end
