module Shipit
  class Rollback < Deploy
    belongs_to :deploy, foreign_key: :parent_id

    state_machine :status do
      after_transition to: :success, do: :lock_reverted_commits
    end

    def rollback?
      true
    end

    def rollbackable?
      false
    end

    def supports_rollback?
      false
    end

    def commits
      return Commit.none unless stack

      @commits ||= stack.commits.reachable.newer_than(until_commit_id).until(since_commit_id).order(id: :asc)
    end

    def commit_range
      [until_commit, since_commit]
    end

    def to_partial_path
      'deploys/deploy'
    end

    private

    def lock_reverted_commits
      stack.lock_reverted_commits!
    end

    def create_commit_deployments
      # Rollback events are confusing in GitHub
    end

    def update_commit_deployments
      # Rollback events are confusing in GitHub
    end
  end
end
