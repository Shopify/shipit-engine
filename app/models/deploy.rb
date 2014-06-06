require 'fileutils'

class Deploy < ActiveRecord::Base
  belongs_to :user
  belongs_to :stack, touch: true, counter_cache: true
  belongs_to :since_commit, class_name: "Commit"
  belongs_to :until_commit, class_name: "Commit"

  has_many :chunks, -> { order(:id) }, class_name: 'OutputChunk'

  scope :success, -> { where(status: 'success') }
  scope :completed, -> { where(status: %w(success error failed)) }
  scope :running, -> { where(status: %w(pending running)) }

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

    after_transition from: :running, do: :rollup_chunks
    after_transition :broadcast_deploy
  end

  after_create :broadcast_deploy

  def author
    user || AnonymousUser.new
  end

  def finished?
    !pending? && !running?
  end

  def commits
    return [] unless stack
    @commits ||= stack.commits.reachable.newer_than(since_commit_id).where('id <= ?', until_commit_id).order(id: :desc)
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
    Resque.enqueue(DeployJob, deploy_id: id, stack_id: stack_id)
  end

  def rollup_chunks
    Resque.enqueue(ChunkRollupJob, deploy_id: id)
  end

  private

  def last_successful_deploy
    stack.deploys.where(:status => "success").last
  end

  def broadcast_deploy
    url = Rails.application.routes.url_helpers.stack_deploy_path(stack, self)
    payload = { id: id, url: url, commit_ids: commits.map(&:id) }.to_json
    event = Pubsubstub::Event.new(payload, name: "deploy.#{status}")
    Pubsubstub::RedisPubSub.publish("stack.#{stack_id}", event)
  end
end
