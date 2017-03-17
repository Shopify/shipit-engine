require 'test_helper'

module Shipit
  class UndeployedCommitsTest < ActiveSupport::TestCase
    setup do
      @real_commit = shipit_commits(:cyclimse_first)
      @commit = UndeployedCommit.new(@real_commit, 0)
      @stack = @commit.stack
    end

    test "#deploy_disallowed? returns false if the commit and the stack are deployable" do
      assert_predicate @commit, :deployable?
      assert_predicate @stack, :deployable?
      refute_predicate @commit, :deploy_disallowed?
    end

    test "#deploy_disallowed? returns false if the commit isn't deployable" do
      @commit.statuses.update_all(state: 'failure')
      refute_predicate @commit, :deployable?
      assert_predicate @stack, :deployable?
      assert_predicate @commit, :deploy_disallowed?
    end

    test "#deploy_disallowed? returns false if the stack isn't deployable" do
      @stack.update!(lock_reason: "Let's eat some chips!")
      assert_predicate @commit, :deployable?
      refute_predicate @stack, :deployable?
      assert_predicate @commit, :deploy_disallowed?
    end

    test "#deploy_too_big? returns false if the commit index is lower than the maximum commits per deploy" do
      assert_equal 2, @stack.maximum_commits_per_deploy
      refute_predicate @commit, :deploy_too_big?
    end

    test "#deploy_too_big? returns true if the commit index is equal or bigger then the maximum commits per deploy" do
      @commit = UndeployedCommit.new(@real_commit, 2)
      assert_equal 2, @stack.maximum_commits_per_deploy
      assert_predicate @commit, :deploy_too_big?
    end

    test "#deploy_state returns `allowed` by default" do
      assert_equal 'allowed', @commit.deploy_state
    end

    test "#deploy_state returns `locked` if the stack is locked" do
      @stack.update!(lock_reason: "Let's eat some chips!")
      assert_equal 'locked', @commit.deploy_state
    end

    test "#deploy_state returns `allowed` if the stack is locked but the safeties are ignored" do
      @stack.update!(lock_reason: "Let's eat some chips!")
      assert_equal 'allowed', @commit.deploy_state(true)
    end

    test "#deploy_state returns `deploying` if the stack is already being deployed" do
      @stack.trigger_deploy(@real_commit, AnonymousUser.new)
      assert_equal 'deploying', @commit.deploy_state
    end

    test "#deploy_state returns `allowed` if the stack is already being deployed but the safeties are ignored" do
      @stack.trigger_deploy(@real_commit, AnonymousUser.new)
      assert_equal 'allowed', @commit.deploy_state(true)
    end

    test "#deploy_state returns the commit state if it isn't deployable" do
      @commit.statuses.update_all(state: 'failure')
      assert_equal 'failure', @commit.deploy_state(true)
    end

    test "#redeploy_state returns `allowed` by default" do
      assert_equal 'allowed', @commit.redeploy_state
    end

    test "#redeploy_state returns `locked` if the stack is locked" do
      @stack.update!(lock_reason: "Let's eat some chips!")
      assert_equal 'locked', @commit.redeploy_state
    end

    test "#redeploy_state returns `allowed` if the stack is locked but the safeties are ignored" do
      @stack.update!(lock_reason: "Let's eat some chips!")
      assert_equal 'allowed', @commit.redeploy_state(true)
    end

    test "#redeploy_state returns `deploying` if the stack is already being deployed" do
      @stack.trigger_deploy(@real_commit, AnonymousUser.new)
      assert_equal 'deploying', @commit.redeploy_state
    end

    test "#redeploy_state returns `allowed` if the stack is already being deployed but the safeties are ignored" do
      @stack.trigger_deploy(@real_commit, AnonymousUser.new)
      assert_equal 'allowed', @commit.redeploy_state(true)
    end

    test "#redeploy_state returns `allowed` even if it isn't deployable" do
      @commit.statuses.update_all(state: 'failure')
      assert_equal 'allowed', @commit.redeploy_state(true)
    end
  end
end
