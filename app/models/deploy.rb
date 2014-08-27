require 'fileutils'

class Deploy < ActiveRecord::Base
  belongs_to :user
  belongs_to :stack, touch: true, counter_cache: true
  belongs_to :since_commit, class_name: "Commit"
  belongs_to :until_commit, class_name: "Commit"

  has_many :chunks, -> { order(:id) }, class_name: 'OutputChunk'

  scope :success,   -> { where(status: 'success') }
  scope :completed, -> { where(status: %w(success error failed)) }
  scope :active,    -> { where(status: %w(pending running)) }

  scope :due_for_rollup, -> { completed.where(rolled_up: false).where('created_at <= ?', 1.hour.ago) }

  state_machine :status, initial: :pending do
    event :run do
      transition pending: :running
    end

    event :failure do
      transition running: :failed
    end

    event :complete do
      transition running: :success
    end

    event :error do
      transition running: :error
    end

    state :pending
    state :running
    state :failed
    state :success
    state :error

    after_transition :broadcast_deploy
    after_transition to: :success, do: :schedule_continuous_delivery
    after_transition to: :success, do: :update_undeployed_commits_count
  end

  after_create :broadcast_deploy

  def build_rollback(user=nil)
    Rollback.new(
      user_id: user.try!(:id),
      stack_id: stack_id,
      parent_id: id,
      since_commit: stack.last_deployed_commit,
      until_commit: since_commit.previous || since_commit
    )
  end

  def trigger_rollback(user)
    rollback = build_rollback(user)
    rollback.save!
    rollback.enqueue
    rollback
  end

  def author
    user || AnonymousUser.new
  end

  def finished?
    !pending? && !running?
  end

  def rollback?
    false
  end

  def commits
    return Commit.none unless stack

    @commits ||= stack.commits.reachable.newer_than(since_commit_id).until(until_commit_id).order(id: :desc)
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

  def working_directory
    File.join(stack.deploys_path, id.to_s)
  end

  def clear_working_directory
    FileUtils.rm_rf(working_directory)
  end

  def write(text)
    chunks.create!(text: text)
  end

  def chunk_output
    chunks.pluck(:text).join("\n")
  end

  def enqueue
    raise "only persisted jobs can be enqueued" unless persisted?
    DeployJob.enqueue(deploy_id: id, stack_id: stack_id)
  end

  def rollup_chunks
    ChunkRollupJob.enqueue(deploy_id: id)
  end

  private

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

  def broadcast_deploy
    url = Rails.application.routes.url_helpers.stack_deploy_path(stack, self)
    payload = { id: id, url: url, commit_ids: commits.map(&:id), stack_status: stack.status, status: status }.to_json
    event = Pubsubstub::Event.new(payload, name: "deploy.#{status}")
    Pubsubstub::RedisPubSub.publish("stack.#{stack_id}", event)
  end
end
