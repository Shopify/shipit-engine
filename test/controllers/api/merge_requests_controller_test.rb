# frozen_string_literal: true
require 'test_helper'

module Shipit
  module Api
    class MergeRequestsControllerTest < ActionController::TestCase
      setup do
        @stack = shipit_stacks(:shipit)
        @merge_request = shipit_merge_requests(:shipit_pending)
        authenticate!
      end

      test "#index returns a list of pull requests" do
        merge_request = @stack.merge_requests.last

        get :index, params: { stack_id: @stack.to_param }
        assert_response :ok
        assert_json '0.id', merge_request.id
      end

      test "#show returns a single pull requests" do
        get :show, params: { stack_id: @stack.to_param, id: @merge_request.number.to_s }
        assert_response :ok
        assert_json 'id', @merge_request.id
      end

      test "#update responds with Accepted if the pull request was queued" do
        assert_enqueued_with(job: RefreshMergeRequestJob) do
          put :update, params: { stack_id: @stack.to_param, id: '64' }
        end
        assert_response :accepted
      end

      test "#update responds with Accepted if the pull request was already queued" do
        assert_enqueued_with(job: RefreshMergeRequestJob) do
          put :update, params: { stack_id: @stack.to_param, id: '65' }
        end
        assert_response :accepted
      end

      test "#update responds with method not allowed if the pull request was already merged" do
        @merge_request.complete!
        put :update, params: { stack_id: @stack.to_param, id: @merge_request.number.to_s }
        assert_response :method_not_allowed
        assert_json 'message', 'This pull request was already merged.'
      end

      test "#destroy cancels the merge if the pull request was waiting" do
        delete :destroy, params: { stack_id: @stack.to_param, id: @merge_request.number.to_s }
        assert_response :no_content
        assert_predicate @merge_request.reload, :canceled?
      end

      test "#destroy silently fail if the pull request was unknown" do
        delete :destroy, params: { stack_id: @stack.to_param, id: '83453489' }
        assert_response :no_content
      end
    end
  end
end
