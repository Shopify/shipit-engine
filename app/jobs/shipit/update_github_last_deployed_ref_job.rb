module Shipit
  class UpdateGithubLastDeployedRefJob < BackgroundJob
    queue_as :default

    # We do not prefix 'refs/' because Octokit methods will do this automatically.
    BRANCH_REF_PREFIX = 'heads'.freeze
    DEPLOY_PREFIX = 'shipit-deploy'.freeze

    def perform(stack)
      stack_sha = stack.last_successful_deploy_commit&.sha
      return unless stack_sha

      environment = stack.environment
      stack_ref = create_full_ref(environment)
      client = Shipit.github.api

      full_repo_name = stack.github_repo_name

      update_or_create_ref(client: client, repo_name: full_repo_name, ref: stack_ref, new_sha: stack_sha)
    end

    private

    def create_full_ref(stack_environment)
      [BRANCH_REF_PREFIX, self::DEPLOY_PREFIX, stack_environment].join("/")
    end

    def create_ref(client:, repo_name:, ref:, sha:)
      client.create_ref(repo_name, ref, sha)
    end

    def update_or_create_ref(client:, repo_name:, ref:, new_sha:)
      client.update_ref(repo_name, ref, new_sha)
    rescue Octokit::UnprocessableEntity => e
      error_msg = e.message
      if error_msg.include? "Reference does not exist"
        create_ref(client: client, repo_name: repo_name, ref: ref, sha: new_sha)
      else
        raise
      end
    end

    def select_target_commit(stack)
      stack.last_successful_deploy_commit&.sha
    end
  end
end
