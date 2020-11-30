# frozen_string_literal: true
module Shipit
  class PredictiveBranchCommands < TaskCommands
    def steps
      deploy_spec.ci_steps!
    end

    def env
      super.merge(
        'BRANCH' => @task.predictive_build.branch,
        'PREDICTIVE_BUILD_ID' => @task.predictive_build.id,
      )
    end

    protected

=begin
    TODO:
    def diff_url
      Shipit::GithubUrlHelper.github_commit_range_url(@stack, *@task.commit_range)
    end
=end
  end
end
