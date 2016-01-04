require 'test_helper'

module Shipit
  module Api
    class LocksControllerTest < ActionController::TestCase
      setup do
        authenticate!
        @stack = shipit_stacks(:shipit)
      end

      test "#create sets a lock" do
        post :create, stack_id: @stack.to_param, reason: 'Just for fun!'
        assert_response :ok
        assert_json 'is_locked', true
        assert_json 'lock_reason', 'Just for fun!'
      end

      test "#create fails if already locked" do
        @stack.update!(lock_reason: "Don't forget me")
        post :create, stack_id: @stack.to_param, reason: 'Just for fun!'
        assert_response :conflict
      end

      test "#update sets a lock" do
        put :update, stack_id: @stack.to_param, reason: 'Just for fun!'
        assert_response :ok
        assert_json 'is_locked', true
        assert_json 'lock_reason', 'Just for fun!'
      end

      test "#update can override a previous lock" do
        @stack.update!(lock_reason: 'Meh...')
        put :update, stack_id: @stack.to_param, reason: 'Just for fun!'
        assert_response :ok
        assert_json 'is_locked', true
        assert_json 'lock_reason', 'Just for fun!'
      end

      test "#destroy clears the lock" do
        @stack.update!(lock_reason: 'Meh...')
        delete :destroy, stack_id: @stack.to_param
        assert_response :ok
        assert_json 'is_locked', false
      end
    end
  end
end
