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

    @stack.transaction do
      shared_parent.try(:detach_children!)
      new_commits.each do |gh_commit|
        @stack.commits.from_github(gh_commit, fetch_status(gh_commit)).save!
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

  def fetch_status(commit)
    Shipit.github_api.statuses(@stack.github_repo_name, commit.sha).first
  end

  def lookup_commit(sha)
    @stack.commits.find_by_sha(sha)
  end

end
