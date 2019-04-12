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

    test "#deploy_discouraged? returns false if the commit index is lower than the maximum commits per deploy" do
      assert_equal 2, @stack.maximum_commits_per_deploy
      refute_predicate @commit, :deploy_discouraged?
    end

    test "#deploy_discouraged? returns true if the commit index is equal or bigger then the maximum commits per deploy" do
      @commit = UndeployedCommit.new(@real_commit, 2)
      assert_equal 2, @stack.maximum_commits_per_deploy
      assert_predicate @commit, :deploy_discouraged?
    end

    test "#deploy_scheduled? returns true if the stack has continuous deployment enabled, commit index is lower then the maximum commits per deploy and commit is not part of active task" do
      commit = UndeployedCommit.new(shipit_commits(:undeployed_4), 1)

      assert_predicate commit.stack, :continuous_deployment
      assert_equal 1, commit.index
      assert_equal 3, commit.stack.maximum_commits_per_deploy
      refute_predicate commit, :active?

      assert_predicate commit, :deploy_scheduled?
    end

    test "#deploy_scheduled? returns false if the stack has continuous deployment enabled and commit index is equal or bigger then the maximum commits per deploy" do
      commit = UndeployedCommit.new(shipit_commits(:undeployed_4), 3)

      assert_predicate commit.stack, :continuous_deployment
      assert_equal 3, commit.index
      assert_equal 3, commit.stack.maximum_commits_per_deploy

      refute_predicate commit, :deploy_scheduled?
    end

    test "#deploy_scheduled? returns false if the stack has continuous deployment disabled" do
      commit = UndeployedCommit.new(shipit_commits(:cyclimse_first), 1)

      refute_predicate commit.stack, :continuous_deployment

      refute_predicate commit, :deploy_scheduled?
    end

    test "#deploy_scheduled? returns false if the commit is part of the active task" do
      commit = UndeployedCommit.new(shipit_commits(:undeployed_3), 1)

      assert_predicate commit.stack, :continuous_deployment
      assert_equal 1, commit.index
      assert_equal 3, commit.stack.maximum_commits_per_deploy
      assert_predicate commit, :active?

      refute_predicate commit, :deploy_scheduled?
    end

    test "#deploy_state returns `allowed` by default" do
      assert_equal 'allowed', @commit.deploy_state
    end

    test "#deploy_state returns `locked` if the commit is locked" do
      @commit.update!(locked: true)
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

    test "#deploy_state returns `blocked` if a previous commit is blocking" do
      blocking_commit = shipit_commits(:soc_second)
      blocking_commit.statuses.delete_all
      assert_predicate blocking_commit, :blocking?

      commit = UndeployedCommit.new(shipit_commits(:soc_third), 0)
      assert_equal 'blocked', commit.deploy_state
    end

    test "#redeploy_state returns `allowed` by default" do
      assert_equal 'allowed', @commit.redeploy_state
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
