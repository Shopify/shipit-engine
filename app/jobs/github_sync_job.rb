class GithubSyncJob < BackgroundJob
  # extend Resque::Plugins::Lock

  @queue = :default

  def perform(params)
    @stack = Stack.find(params[:stack_id])
    repo  = @stack.github_repo

    commits = fetch_missing_commits(repo.rels[:commits])
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
