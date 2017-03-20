require 'test_helper'

module Shipit
  class CommitsControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @commit = shipit_commits(:first)
      session[:user_id] = shipit_users(:walrus).id
    end

    test "#update allows to lock a commit" do
      refute_predicate @commit, :locked?
      patch :update, params: {stack_id: @stack.to_param, id: @commit.id, commit: {locked: true}}
      assert_response :ok
      assert_predicate @commit.reload, :locked?
    end
  end
end
