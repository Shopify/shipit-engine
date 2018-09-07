require 'test_helper'

module Shipit
  class ReleaseStatusesControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @deploy = shipit_deploys(:shipit)
      session[:user_id] = shipit_users(:walrus).id
    end

    test ":create allow users to append release statuses" do
      assert_difference -> { ReleaseStatus.count }, +1 do
        post :create, params: {stack_id: @stack, deploy_id: @deploy.id, status: 'success'}
        assert_response :created
      end

      status = ReleaseStatus.last
      assert_equal 'success', status.state
      assert_equal '@walrus signaled this release as healthy.', status.description
      assert_equal @deploy.permalink, status.target_url
    end
  end
end
