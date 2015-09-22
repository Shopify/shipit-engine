require 'fileutils'

class Deploy < Task
  CONFIRMATIONS_REQUIRED = 5

  state_machine :status do
    after_transition to: :success, do: :schedule_continuous_delivery
    after_transition to: :success, do: :update_undeployed_commits_count
    after_transition to: :aborted, do: :trigger_revert_if_required
  end

  before_create :denormalize_commit_stats
  after_commit :broadcast_update

  delegate :broadcast_update, to: :stack

  def build_rollback(user = nil, env: nil)
    Rollback.new(
      user_id: user.try!(:id),
      stack_id: stack_id,
      parent_id: id,
      since_commit: stack.last_deployed_commit,
      until_commit: until_commit,
      env: env || {},
    )
  end

  # Rolls the stack back to this deploy
  def trigger_rollback(user = AnonymousUser.new, env: nil)
    rollback = build_rollback(user, env: env)
    rollback.save!
    rollback.enqueue

    lock_reason = "A rollback for #{rollback.since_commit.sha} has been triggered. " \
      "Please make sure the reason for the rollback has been addressed before deploying again."
    stack.update!(lock_reason: lock_reason, lock_author_id: user.id)

    rollback
  end

  # Rolls the stack back to the **previous** deploy
  def trigger_revert
    rollback = Rollback.create!(
      user_id: user_id,
      stack_id: stack_id,
      parent_id: id,
      since_commit: until_commit,
      until_commit: since_commit,
    )
    rollback.enqueue
    lock_reason = "A rollback for #{until_commit.sha} has been triggered. " \
      "Please make sure the reason for the rollback has been addressed before deploying again."
    stack.update!(lock_reason: lock_reason, lock_author_id: user_id)
    rollback
  end

  def rollback?
    false
  end

  def commit_range
    [since_commit, until_commit]
  end

  delegate :supports_rollback?, to: :stack

  def rollbackable?
    success? && supports_rollback? && !currently_deployed?
  end

  def currently_deployed?
    until_commit_id == stack.last_deployed_commit.try!(:id)
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
    super || default_since_commit_id
  end

  def variables
    stack.deploy_variables
  end

  def reject!
    return if failed?
    transaction do
      flap! unless flapping?
      update!(confirmations: [confirmations - 1, -1].min)
      failure! if confirmed?
    end
  end

  def accept!
    return if success?
    transaction do
      flap! unless flapping?
      update!(confirmations: [confirmations + 1, 1].max)
      complete! if confirmed?
    end
  end

  def confirmed?
    confirmations.abs >= CONFIRMATIONS_REQUIRED
  end

  private

  def trigger_revert_if_required
    return unless rollback_once_aborted?
    return unless supports_rollback?
    trigger_revert
  end

  def default_since_commit_id
    return unless stack
    @default_since_commit_id ||= last_successful_deploy.try!(:until_commit_id)
  end

  def denormalize_commit_stats
    self.additions = commits.map(&:additions).compact.sum
    self.deletions = commits.map(&:deletions).compact.sum
  end

  def schedule_continuous_delivery
    return unless stack.continuous_deployment?

    to_deploy = stack.commits.order(:id).newer_than(until_commit).successful.last
    return unless to_deploy

    stack.trigger_deploy(to_deploy, to_deploy.committer)
  end

  def last_successful_deploy
    stack.deploys.where(status: "success").last
  end

  def update_undeployed_commits_count
    stack.update_undeployed_commits_count(until_commit)
  end
end
