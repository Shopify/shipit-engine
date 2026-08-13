# frozen_string_literal: true

module Shipit
  class GithubSyncJob < BackgroundJob
    include BackgroundJob::Unique

    attr_reader :stack

    MAX_FETCHED_COMMITS = 25
    MAX_RETRY_ATTEMPTS = 5
    RETRY_DELAY = 5.seconds
    queue_as :default
    on_duplicate :drop

    self.timeout = 60
    self.lock_timeout = 20

    def perform(params)
      @stack = Stack.find(params[:stack_id])
      expected_head_sha = params[:expected_head_sha]
      retry_count = params[:retry_count] || 0
      head_before_sync = spec_cache_target
      appended_commits = []

      handle_github_errors do
        new_commits, shared_parent = fetch_missing_commits { stack.github_commits }

        # Retry on Github eventual consistency: webhook indicated new commits but we found none
        if expected_head_sha && new_commits.empty? && !commit_exists?(expected_head_sha) &&
           retry_count < MAX_RETRY_ATTEMPTS
          GithubSyncJob.set(wait: RETRY_DELAY * retry_count).perform_later(params.merge(retry_count: retry_count + 1))
          return
        end

        stack.transaction do
          shared_parent&.detach_children!
          appended_commits = new_commits.map do |gh_commit|
            append_commit(gh_commit)
          end
          stack.lock_reverted_commits! if appended_commits.any?(&:revert?)
        end
      end
      sync_changed_nothing = appended_commits.empty? &&
                             spec_cache_target == head_before_sync &&
                             stack.cached_deploy_spec.present?
      return if sync_changed_nothing && !params[:force_spec_cache]

      CacheDeploySpecJob.perform_later(stack)
    end

    def append_commit(gh_commit)
      stack.commits.create_from_github!(gh_commit)
    end

    def fetch_missing_commits(&block)
      commits = []
      github_api = stack&.github_api
      iterator = Shipit::FirstParentCommitsIterator.new(github_api:, &block)
      iterator.each_with_index do |commit, index|
        break if index >= MAX_FETCHED_COMMITS

        if shared_parent = lookup_commit(commit.sha)
          return commits, shared_parent
        end

        commits.unshift(commit)
      end
      [commits, nil]
    end

    protected

    # The commit CacheDeploySpecJob would check out: the newest reachable one.
    # If it didn't change during the sync (no appends, no detaches), the cached
    # spec is still accurate and doesn't need to be recomputed.
    def spec_cache_target
      stack.commits.reachable.last&.sha
    end

    def handle_github_errors
      yield
    rescue Octokit::NotFound
      stack.mark_as_inaccessible!
    rescue Shipit::GithubOrganizationUnknown => e
      Rails.logger.warn("GithubSyncJob: unknown GitHub organization #{e.message} for stack #{stack.id}")
      stack.mark_as_inaccessible!
    else
      stack.mark_as_accessible!
    end

    def lookup_commit(sha)
      stack.commits.find_by(sha:)
    end

    def commit_exists?(sha)
      stack.commits.exists?(sha:)
    end
  end
end
