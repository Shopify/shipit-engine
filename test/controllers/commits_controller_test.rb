# frozen_string_literal: true

require 'test_helper'

module Shipit
  class CommitsControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @commit = shipit_commits(:first)
      @user = shipit_users(:walrus)
      session[:user_id] = @user.id
    end

    test "#update allows commits to be locked and sets the lock author" do
      refute_predicate(@commit, :locked?)

      patch(:update, params: {
              stack_id: @stack.to_param,
              id: @commit.id,
              commit: { locked: true }
            })

      assert_response(:ok)
      @commit.reload
      assert_predicate(@commit, :locked?)
      assert_equal(@user, @commit.lock_author)
    end

    test "#update allows commits to be unlocked and clears the lock author" do
      @commit.lock(@user)

      patch(:update, params: {
              stack_id: @stack.to_param,
              id: @commit.id,
              commit: { locked: false }
            })

      assert_response(:ok)
      @commit.reload
      refute_predicate(@commit, :locked?)
      assert_nil(@commit.lock_author_id)
    end
  end
end
