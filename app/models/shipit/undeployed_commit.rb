# frozen_string_literal: true

module Shipit
  class UndeployedCommit < DelegateClass(Commit)
    attr_reader :index

    def initialize(commit, index:, next_expected_commit_to_deploy: nil)
      super(commit)
      @index = index
      @next_expected_commit_to_deploy = next_expected_commit_to_deploy
    end

    def deploy_state(bypass_safeties = false)
      state = deployable? ? 'allowed' : status.state

      unless bypass_safeties
        if blocked?
          state = 'blocked'
        elsif locked?
          state = 'locked'
        elsif stack.active_task?
          state = 'deploying'
        end
      end
      state
    end

    def redeploy_state(bypass_safeties = false)
      state = 'allowed'
      unless bypass_safeties
        state = 'deploying' if stack.active_task?
      end
      state
    end

    def deploy_disallowed?
      !deployable? || !stack.deployable?
    end

    def deploy_discouraged?
      stack.maximum_commits_per_deploy && index >= stack.maximum_commits_per_deploy
    end

    def expected_to_be_deployed?
      return false if @next_expected_commit_to_deploy.nil?
      return false unless stack.continuous_deployment
      return false if active?

      id <= @next_expected_commit_to_deploy.id
    end

    def blocked?
      return @blocked if defined?(@blocked)
      @blocked = super
    end
  end
end
