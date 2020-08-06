# frozen_string_literal: true
require 'test_helper'

module Shipit
  class MergeRequestsControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @pr = shipit_merge_requests(:shipit_pending)
      session[:user_id] = shipit_users(:walrus).id
    end

    test "#index shows pending pull requests" do
      get :index, params: { stack_id: @stack.to_param }
      assert_response :success
      assert_select '.pr-list .pr', @stack.merge_requests.pending.count
    end

    test "#add can enqueue a pull request" do
      assert_difference -> { MergeRequest.count }, +1 do
        post :create, params: { stack_id: @stack.to_param, number_or_url: '#5' }
      end
      assert_redirected_to stack_merge_requests_path(@stack)
    end

    test "#destroy can cancel a pending pull request" do
      assert_predicate @pr, :pending?
      delete :destroy, params: { stack_id: @stack.to_param, id: @pr.id }
      assert_redirected_to stack_merge_requests_path(@stack)
      assert_predicate @pr.reload, :canceled?
    end
  end
end
