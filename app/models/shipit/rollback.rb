# frozen_string_literal: true

module Shipit
  class Rollback < Deploy
    belongs_to :deploy, foreign_key: :parent_id, inverse_of: false

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

    def report_complete!
      complete!
    end

    private

    def update_release_status
      return unless stack.release_status?

      # When we rollback to a certain revision, assume that all later deploys were faulty
      stack.deploys.newer_than(deploy.id).until(stack.last_completed_deploy.id).to_a.each do |deploy|
        next if deploy.id == id
        deploy.report_faulty!(description: "A rollback of #{stack.to_param} was triggered")
      end
    end

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
