module Shipit
  class Rollback < Deploy
    belongs_to :deploy, foreign_key: :parent_id

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

    def create_commit_deployments
      # Rollback events are confusing in GitHub
    end

    def update_commit_deployments
      # Rollback events are confusing in GitHub
    end
  end
end
