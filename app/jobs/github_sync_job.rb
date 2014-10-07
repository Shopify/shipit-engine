class GithubSyncJob < BackgroundJob
  @queue = :default

  self.timeout = 60

  extend Resque::Plugins::Workers::Lock

  def self.lock_workers(params)
    "github-sync-#{params[:stack_id]}"
  end

  def perform(params)
    @stack = Stack.find(params[:stack_id])

    new_commits, shared_parent = fetch_missing_commits(@stack.github_commits)

    new_commit_ids = []

    @stack.transaction do
      shared_parent.try(:detach_children!)
      new_commits.each do |gh_commit|
        commit = @stack.commits.from_github(gh_commit).save!
        commit.refresh_statuses
      end
    end
  end

  def fetch_missing_commits(relation)
    commits = []
    iterator = FirstParentCommitsIterator.new(relation)
    iterator.each do |commit|
      if shared_parent = lookup_commit(commit.sha)
        return commits, shared_parent
      end
      commits.unshift(commit)
    end
    return commits, nil
  end

  protected

  def lookup_commit(sha)
    @stack.commits.find_by_sha(sha)
  end

end
