class Task < ActiveRecord::Base
  belongs_to :user
  belongs_to :stack, touch: true, counter_cache: true
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
  end

  def rollup_chunks
    Resque.enqueue(ChunkRollupJob, deploy_id: id)
  end

  def write(text)
    chunks.create!(text: text)
  end

  def chunk_output
    chunks.pluck(:text).join("\n")
  end

  def rollback?
    false
  end

  def author
    user || AnonymousUser.new
  end

  def finished?
    !pending? && !running?
  end

  def pid
    Rails.cache.read("task:#{id}:pid")
  end

  def pid=(pid)
    Rails.cache.write("task:#{id}:pid", pid, expires_in: 1.hour)
  end

  def abort!
    target_pid = pid
    return unless target_pid.present?
    Process.kill('TERM', target_pid)
  rescue Errno::ESRCH
    true
  end

end
