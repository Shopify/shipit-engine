module Shipit
  class PullRequest < ApplicationRecord
    belongs_to :stack
    belongs_to :head, class_name: 'Shipit::Commit'

    validates :number, presence: true, uniqueness: {scope: :stack_id}

    state_machine :merge_status, initial: :fetching do
      state :fetching
      state :pending
      state :rejected
      state :canceled
      state :merged

      event :fetched do
        transition fetching: :pending
      end

      event :reject do
        transition pending: :rejected
      end

      event :cancel do
        transition pending: :canceled
      end

      event :complete do
        transition pending: :complete
      end

      event :retry do
        transition %i(rejected canceled) => :pending
      end
    end

    def self.request_merge!(stack, number)
      pull_request = begin
        create_with(merge_requested_at: Time.now.utc).find_or_create_by!(
          stack: stack,
          number: number,
        )
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      pull_request.schedule_refresh!
      pull_request
    end

    def schedule_refresh!
      RefreshPullRequestJob.perform_later(self)
    end

    def refresh!
      update!(github_pull_request: Shipit.github_api.pull_request(stack.github_repo_name, number))
      head.refresh_statuses!
      fetched! if fetching?
    end

    def github_pull_request=(github_pull_request)
      self.github_id = github_pull_request.id
      self.api_url = github_pull_request.url
      self.title = github_pull_request.title
      self.state = github_pull_request.state
      self.mergeable = github_pull_request.mergeable
      self.additions = github_pull_request.additions
      self.deletions = github_pull_request.deletions
      self.head = find_or_create_commit_from_github_by_sha!(github_pull_request.head.sha, detached: true)
    end

    private

    def find_or_create_commit_from_github_by_sha!(sha, attributes)
      if commit = stack.commits.by_sha(sha)
        return commit
      else
        github_commit = Shipit.github_api.commit(stack.github_repo_name, sha)
        stack.commits.create_from_github!(github_commit, attributes)
      end
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end
end
