module Shipit
  class UpdateGithubPendingDeployRefJob < UpdateGithubLastDeployedRefJob
    queue_as :default

    DEPLOY_PREFIX = 'shipit-deploy-pending'.freeze

    private

    def select_target_commit(stack)
      stack.next_expected_commit_to_deploy.sha
    end
  end
end
