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
        state = 'deploying' if stack.active_task?
        state = 'locked' if locked?
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

    def deploy_too_big?
      stack.maximum_commits_per_deploy && index >= stack.maximum_commits_per_deploy
    end
  end
end
