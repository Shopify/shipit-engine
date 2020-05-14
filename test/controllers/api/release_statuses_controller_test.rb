# frozen_string_literal: true
require 'test_helper'

module Shipit
  module Api
    class ReleaseStatusesControllerTest < ActionController::TestCase
      setup do
        authenticate!
        @stack = shipit_stacks(:shipit_canaries)
        @deploy = shipit_deploys(:canaries_validating)
      end

      test "#create renders a 422 if status is not found" do
        post :create, params: { stack_id: @stack.to_param, deploy_id: @deploy.id }
        assert_response :unprocessable_entity
        assert_json 'errors', 'status' => ['is required', 'is not included in the list']
      end

      test "#create renders a 422 if status is invalid" do
        assert_no_difference -> { ReleaseStatus.count } do
          post :create, params: {
            stack_id: @stack.to_param,
            deploy_id: @deploy.id,
            status: 'foo',
          }
        end

        assert_response :unprocessable_entity
        assert_json 'errors', 'status' => ['is not included in the list']
      end

      test "#create allow users to append release statuses and mark the deploy as success" do
        assert_difference -> { ReleaseStatus.count }, +1 do
          post :create, params: {
            stack_id: @stack.to_param,
            deploy_id: @deploy.id,
            status: 'success',
          }
          assert_response :created
        end

        status = ReleaseStatus.last
        assert_equal 'success', status.state
        assert_equal '@anonymous signaled this release as healthy.', status.description
        assert_equal @deploy.permalink, status.target_url
        assert_equal 'success', @deploy.reload.status
      end

      test "#create allow users to append release statuses and mark the deploy as faulty" do
        assert_difference -> { ReleaseStatus.count }, +1 do
          post :create, params: {
            stack_id: @stack.to_param,
            deploy_id: @deploy.id,
            status: 'failure',
          }
          assert_response :created
        end

        status = ReleaseStatus.last
        assert_equal 'failure', status.state
        assert_equal '@anonymous signaled this release as faulty.', status.description
        assert_equal @deploy.permalink, status.target_url
        assert_equal 'faulty', @deploy.reload.status
      end
    end
  end
end
