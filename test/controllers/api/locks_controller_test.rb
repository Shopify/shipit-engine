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
        assert_json { |json| assert_not_nil json['locked_since'] }
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

      test "#update does not override previous locked_since" do
        since = Time.current.round
        @stack.update!(lock_reason: 'Meh...', locked_since: since)
        put :update, stack_id: @stack.to_param, reason: 'Just for fun!'
        assert_response :ok
        assert_json 'locked_since', since.utc.iso8601(3)
      end

      test "#destroy clears the lock" do
        @stack.update!(lock_reason: 'Meh...', locked_since: Time.current)
        delete :destroy, stack_id: @stack.to_param
        assert_response :ok
        assert_json 'is_locked', false
        assert_json { |json| assert_nil json['locked_since'] }
      end
    end
  end
end
