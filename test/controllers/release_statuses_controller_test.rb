require 'test_helper'

module Shipit
  class ReleaseStatusesControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit_canaries)
      @deploy = shipit_deploys(:canaries_validating)
      session[:user_id] = shipit_users(:walrus).id
    end

    test ":create allow users to append release statuses and mark the deploy as success" do
      assert_difference -> { ReleaseStatus.count }, +1 do
        post :create, params: {stack_id: @stack, deploy_id: @deploy.id, status: 'success'}
        assert_response :created
      end

      status = ReleaseStatus.last
      assert_equal 'success', status.state
      assert_equal '@walrus signaled this release as healthy.', status.description
      assert_equal @deploy.permalink, status.target_url
      assert_equal 'success', @deploy.reload.status
    end

    test ":create allow users to append release statuses and mark the deploy as faulty" do
      assert_difference -> { ReleaseStatus.count }, +1 do
        post :create, params: {stack_id: @stack, deploy_id: @deploy.id, status: 'failure'}
        assert_response :created
      end

      status = ReleaseStatus.last
      assert_equal 'failure', status.state
      assert_equal '@walrus signaled this release as faulty.', status.description
      assert_equal @deploy.permalink, status.target_url
      assert_equal 'faulty', @deploy.reload.status
    end
  end
end
