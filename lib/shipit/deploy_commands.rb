# frozen_string_literal: true
module Shipit
  class DeployCommands < TaskCommands
    def steps
      deploy_spec.deploy_steps!
    end

    def env
      commit = @task.until_commit
      mrs = Shipit::MergeRequest.where("stack_id = #{@stack.id}")
                                .where("head_id > #{@task.since_commit.id} and head_id < #{@task.until_commit.id}" )
                                .where(merge_status: 'merged')
      commits_sha = ''
      mrs.each do |c|
        commits_sha = commits_sha + ',' if commits_sha != ''
        commits_sha = commits_sha + c.head.sha
      end

      super.merge(
        'SHA' => commit.sha,
        'REVISION' => commit.sha,
        'DIFF_LINK' => diff_url,
        'COMMITS' => commits_sha,
      )
    end

    protected

    def diff_url
      Shipit::GithubUrlHelper.github_commit_range_url(@stack, *@task.commit_range)
    end
  end
end
