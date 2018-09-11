require 'test_helper'

module Shipit
  class AppendDelayedReleaseStatusJobTest < ActiveSupport::TestCase
    setup do
      @job = AppendDelayedReleaseStatusJob.new
      @deploy = shipit_deploys(:shipit_complete)
    end

    test "#perform bails out if another status was appended in the meantime" do
      cursor = @deploy.last_release_status
      @deploy.append_release_status(cursor.state, 'Something else happened')
      assert_no_difference -> { ReleaseStatus.count } do
        @job.perform(@deploy, cursor: cursor, status: 'success', description: 'Nothing happened')
      end
    end

    test "#perform appends the new status if no other status was appended in the meantime" do
      cursor = @deploy.last_release_status
      assert_difference -> { ReleaseStatus.count }, +1 do
        @job.perform(@deploy, cursor: cursor, status: 'success', description: 'Something happened')
      end
    end
  end
end
