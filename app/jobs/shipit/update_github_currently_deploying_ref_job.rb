module Shipit
  class UpdateGithubCurrentlyDeployingRefJob < UpdateGithubLastDeployedRefJob
    queue_as :default

    DEPLOY_PREFIX = 'shipit-deploy-deploying'.freeze

    private

    def select_target_commit(stack)
      commits = @stack.undeployed_commits do |scope|
        scope.preload(:author, :statuses, :check_runs, :lock_author)
      end

      # TODO: Need to sort?
      @active_commits = commits.select { |commit| commit.active? }.last
    end
  end
end
