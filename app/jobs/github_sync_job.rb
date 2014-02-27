class GithubSyncJob
  def perform(params)
    stack = Stack.find(params[:stack_id])
    repo  = stack.github_repo

    commits = fetch_missing_commits(stack, repo.rels[:commits])

    commits.reverse.map { |c| stack.commits.from_github(c) }.each(&:save!)
  end

  def fetch_missing_commits(stack, relation)
    commits = []

    2.times do
      resource = relation.get
      resource.data.map do |commit|
        return commits if stack.commits.where(:sha => commit.sha).exists?
        commits << commit
      end

      relation = resource.rels[:next]
      break if relation.nil?
    end

    commits
  end
end
