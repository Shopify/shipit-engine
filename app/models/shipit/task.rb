module Shipit
  class Task < ActiveRecord::Base
    belongs_to :deploy, foreign_key: :parent_id, required: false # required for fixtures

    belongs_to :user
    belongs_to :stack, touch: true, counter_cache: true
    belongs_to :until_commit, class_name: 'Commit'
    belongs_to :since_commit, class_name: 'Commit'

    has_many :chunks, -> { order(:id) }, class_name: 'OutputChunk', dependent: :destroy

    serialize :definition, TaskDefinition
    serialize :env, Hash

    scope :success, -> { where(status: 'success') }
    scope :completed, -> { where(status: %w(success error failed flapping aborted)) }
    scope :active, -> { where(status: %w(pending running aborting)) }
    scope :exclusive, -> { where(allow_concurrency: false) }

    scope :due_for_rollup, -> { completed.where(rolled_up: false).where('created_at <= ?', 1.hour.ago) }

    after_save :record_status_change
    after_commit :emit_hooks

    state_machine :status, initial: :pending do
      after_transition any => %i(success failed error) do |task|
        task.async_refresh_deployed_revision
      end

      after_transition any => :flapping do |task|
        task.update!(confirmations: 0)
      end

      event :run do
        transition pending: :running
      end

      event :failure do
        transition %i(running flapping) => :failed
      end

      event :complete do
        transition %i(running flapping) => :success
      end

      event :error do
        transition all => :error
      end

      event :aborting do
        transition all - %i(aborted) => :aborting
      end

      event :aborted do
        transition aborting: :aborted
      end

      event :flap do
        transition %i(failed error success) => :flapping
      end

      state :pending
      state :running
      state :failed
      state :success
      state :error
      state :aborting
      state :aborted
      state :flapping
    end

    def report_failure!(_error)
      reload
      if aborting?
        aborted!
      else
        failure!
      end
    end

    def report_error!(error)
      write("#{error.class}: #{error.message}\n\t#{error.backtrace.join("\t")}\n")
      error!
    end

    delegate :acquire_git_cache_lock, :async_refresh_deployed_revision, to: :stack

    delegate :checklist, to: :definition

    def spec
      @spec ||= DeploySpec::FileSystem.new(working_directory, stack.environment)
    end

    def enqueue
      raise "only persisted jobs can be enqueued" unless persisted?
      PerformTaskJob.perform_later(self)
    end

    def write(text)
      chunks.create!(text: text)
    end

    def chunk_output
      if rolled_up?
        output
      else
        chunks.pluck(:text).join
      end
    end

    def schedule_rollup_chunks
      ChunkRollupJob.perform_later(self)
    end

    def rollup_chunks
      ActiveRecord::Base.transaction do
        self.output = chunk_output
        chunks.delete_all
        update_attribute(:rolled_up, true)
      end
    end

    def output
      gzip = self[:gzip_output]

      if gzip.nil? || gzip.empty?
        ''
      else
        ActiveSupport::Gzip.decompress(gzip)
      end
    end

    def output=(string)
      self[:gzip_output] = ActiveSupport::Gzip.compress(string)
    end

    def rollback?
      false
    end

    def rollbackable?
      false
    end

    def supports_rollback?
      false
    end

    def author
      user || AnonymousUser.new
    end

    def finished?
      !pending? && !running? && !aborting?
    end

    def pid
      pid = Shipit.redis.get("task:#{id}:pid")
      pid.presence && pid.to_i
    end

    def pid=(pid)
      Shipit.redis.set("task:#{id}:pid", pid, ex: 1.hour.to_i)
    end

    def abort!(rollback_once_aborted: false)
      target_pid = pid
      return write("\nAbort: failed, PID unknown\n") unless target_pid.present?

      update!(rollback_once_aborted: rollback_once_aborted)
      aborting!
      write("\nAbort: sending SIGTERM to pid #{target_pid}\n")
      Process.kill('TERM', target_pid)
    rescue Errno::ESRCH
      write("\nAbort: PID #{target_pid} ESRCH: No such process\n")
      aborted!
      true
    end

    def working_directory
      File.join(stack.deploys_path, id.to_s)
    end

    def record_status_change
      @status_changed ||= status_changed?
    end

    def emit_hooks
      return unless @status_changed
      @status_changed = nil
      Hook.emit(hook_event, stack, hook_event => self, status: status, stack: stack)
    end

    def hook_event
      self.class.name.demodulize.underscore.to_sym
    end
  end
end
