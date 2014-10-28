require 'fileutils'

class Deploy < Task
  state_machine :status do
    after_transition to: :success, do: :schedule_continuous_delivery
    after_transition to: :success, do: :update_undeployed_commits_count
  end

  before_create :denormalize_commit_stats
  after_commit :broadcast_update

  delegate :broadcast_update, to: :stack

  def build_rollback(user=nil)
    Rollback.new(
      user_id: user.try!(:id),
      stack_id: stack_id,
      parent_id: id,
      since_commit: stack.last_deployed_commit,
      until_commit: since_commit
    )
  end

  def trigger_rollback(user)
    rollback = build_rollback(user)
    rollback.save!
    rollback.enqueue

    lock_reason = "A rollback for #{rollback.since_commit.sha} has been triggered. " \
      "Please make sure the reason for the rollback has been addressed before deploying again."
    stack.update_attribute(:lock_reason, lock_reason)

    rollback
  end

  def rollback?
    false
  end

  def commits
    return Commit.none unless stack

    @commits ||= stack.commits.reachable.newer_than(since_commit_id).until(until_commit_id).order(id: :desc)
  end

  def commits_since
    return Commit.none unless stack

    @commits_since ||= stack.commits.reachable.newer_than(until_commit_id).order(id: :desc)
  end

  def since_commit_id
    if value = read_attribute(:since_commit_id)
      value
    elsif stack
      @default_since_commit_id ||= last_successful_deploy.try(:until_commit_id)
    else
      nil
    end
  end

  private

  def denormalize_commit_stats
    self.additions = commits.map(&:additions).sum
    self.deletions = commits.map(&:deletions).sum
  end

  def schedule_continuous_delivery
    return unless stack.continuous_deployment?

    to_deploy = stack.commits.order(:id).newer_than(until_commit).successful.last
    if to_deploy
      stack.trigger_deploy(to_deploy, to_deploy.committer)
    end
  end

  def last_successful_deploy
    stack.deploys.where(:status => "success").last
  end

  def update_undeployed_commits_count
    stack.update_undeployed_commits_count(until_commit)
  end
end
