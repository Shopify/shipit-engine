class GithubSyncJob < BackgroundJob
  @queue = :default

  extend Resque::Plugins::Workers::Lock

  def self.lock_workers(params)
    "github-sync-#{params[:stack_id]}"
  end

  def perform(params)
    @stack = Stack.find(params[:stack_id])
    commits = fetch_missing_commits(@stack.github_commits)
    commits.reverse.each do |gh_commit|
      @stack.commits.from_github(gh_commit, fetch_state(gh_commit)).save!
    end
  end

  def fetch_missing_commits(relation)
    commits = []
    iterator = FirstParentCommitsIterator.new(relation)
    iterator.each do |commit|
      return commits if known?(commit.sha)
      commits << commit
    end
    commits
  end

  protected

  def fetch_state(commit)
    Shipit.github_api.statuses(@stack.github_repo_name, commit.sha).first.try(:state)
  end

  def known?(sha)
    @stack.commits.where(sha: sha).exists?
  end

end
