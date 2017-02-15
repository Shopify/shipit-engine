require 'test_helper'

module Shipit
  class PullRequestsControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      session[:user_id] = shipit_users(:walrus).id
    end

    test "#index shows pending pull requests" do
      get :index, params: {stack_id: @stack.to_param}
      assert_response :success
      assert_select '.pr-list .pr', @stack.pull_requests.pending.count
    end
  end
end
