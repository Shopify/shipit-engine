module Shipit
  class CreateDeploymentsForTaskJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    def perform(task)
      # Create one deployment for the head of the batch
      task.commit_deployments.create!(sha: task.until_commit.sha)

      # Create one for each pull request in the batch, to give feedback on the PR timeline
      task.commits.select(&:pull_request?).each do |commit|
        task.commit_deployments.create!(sha: pull_request_head_for_commit(commit))
      end

      # Immediately update to publish the status to the commit deployments
      task.update_commit_deployments
    end

    private

    def pull_request_head_for_commit(commit)
      pull_request = Shipit.github.api.pull_request(commit.stack.github_repo_name, commit.pull_request_number)
      pull_request.head.sha
    end
  end
end
