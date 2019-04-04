module Shipit
  class UndeployedCommit < DelegateClass(Commit)
    attr_reader :index

    def initialize(commit, index)
      super(commit)
      @index = index
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
      maximum_commits_per_deploy_reached?
    end

    def deploy_scheduled?
      stack.continuous_deployment && !maximum_commits_per_deploy_reached? && !active?
    end

    def blocked?
      return @blocked if defined?(@blocked)
      @blocked = super
    end

    private

    def maximum_commits_per_deploy_reached?
      stack.maximum_commits_per_deploy && index >= stack.maximum_commits_per_deploy
    end
  end
end
