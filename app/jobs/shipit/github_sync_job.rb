module Shipit
  class GithubSyncJob < BackgroundJob
    include BackgroundJob::Unique

    MAX_FETCHED_COMMITS = 10
    queue_as :default

    self.timeout = 60
    self.lock_timeout = 20

    def perform(params)
      @stack = Stack.find(params[:stack_id])

      handle_github_errors do
        new_commits, shared_parent = fetch_missing_commits { @stack.github_commits }

        @stack.transaction do
          shared_parent.try!(:detach_children!)
          new_commits.each do |gh_commit|
            append_commit(gh_commit)
          end
        end
      end
      CacheDeploySpecJob.perform_later(@stack)
    end

    def append_commit(gh_commit)
      appended_commit = @stack.commits.create_from_github!(gh_commit)
      if appended_commit.revert?
        impacted_commits = @stack.undeployed_commits.reverse.drop_while { |c| !appended_commit.revert_of?(c) }
        impacted_commits.pop # appended_commit
        impacted_commits.each do |impacted_commit|
          impacted_commit.update!(locked: true)
        end
      end
    end

    def fetch_missing_commits(&block)
      commits = []
      iterator = Shipit::FirstParentCommitsIterator.new(&block)
      iterator.each_with_index do |commit, index|
        break if index >= MAX_FETCHED_COMMITS

        if shared_parent = lookup_commit(commit.sha)
          return commits, shared_parent
        end
        commits.unshift(commit)
      end
      return commits, nil
    end

    protected

    def handle_github_errors
      yield
    rescue Octokit::NotFound
      @stack.mark_as_inaccessible!
    else
      @stack.mark_as_accessible!
    end

    def lookup_commit(sha)
      @stack.commits.find_by_sha(sha)
    end
  end
end
