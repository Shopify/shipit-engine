class GithubSyncJob < BackgroundJob
  # extend Resque::Plugins::Lock

  @queue = :default

  def perform(params)
    @stack = Stack.find(params[:stack_id])

    new_commits, shared_parent = fetch_missing_commits(@stack.github_commits)
    @stack.transaction do
      shared_parent.try(:detach_children!)
      new_commits.each do |gh_commit|
        @stack.commits.from_github(gh_commit, fetch_state(gh_commit)).save!
      end
    end
  end

  def fetch_missing_commits(relation)
    commits = []
    iterator = FirstParentCommitsIterator.new(relation)
    iterator.each do |commit|
      if shared_parent = known?(commit.sha)
        return commits.reverse, shared_parent
      end
      commits << commit
    end
    return commits, nil
  end

  protected

  def fetch_state(commit)
    Shipit.github_api.statuses(@stack.github_repo_name, commit.sha).first.try(:state)
  end

  def known?(sha)
    @stack.commits.where(sha: sha).exists?
  end

end
