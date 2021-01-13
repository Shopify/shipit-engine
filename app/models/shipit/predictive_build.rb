# frozen_string_literal: true

module Shipit
  class PredictiveBuild < Record
    belongs_to :pipeline
    has_many :predictive_build_tasks
    has_many :predictive_branches

    WAITING_STATUSES = %w(pending).freeze
    WIP_STATUSES = %w(pending ci_stack_tasks ci_pipeline_run ci_pipeline_running ci_pipeline_verification ci_pipeline_verifying ci_pipeline_verified ci_pipeline_canceling waiting_for_merging).freeze

    state_machine :status, initial: :pending do
      state :pending
      state :ci_stack_tasks
      state :ci_stack_tasks_failed
      state :ci_pipeline_run
      state :ci_pipeline_running
      state :ci_pipeline_verification
      state :ci_pipeline_verifying
      state :ci_pipeline_verified
      state :ci_pipeline_canceling
      state :ci_pipeline_failed
      state :failed_commits_validation
      state :waiting_for_merging
      state :merging_failed
      state :completed
      state :failed
      state :rejected
      state :canceled

      event :stack_tasks do
        transition any => :ci_stack_tasks
      end
      event :ci_stack_tasks_failed do
        transition any => :ci_stack_tasks_failed
      end

      event :pipeline_tasks do
        transition any => :ci_pipeline_run
      end

      event :ci_pipeline_running do
        transition any => :ci_pipeline_running
      end

      event :ci_pipeline_verification do
        transition any => :ci_pipeline_verification
      end

      event :ci_pipeline_verifying do
        transition any => :ci_pipeline_verifying
      end

      event :ci_pipeline_verified do
        transition any => :ci_pipeline_verified
      end

      event :ci_pipeline_canceling do
        transition any => :ci_pipeline_canceling
      end

      event :ci_pipeline_failed do
        transition any => :ci_pipeline_failed
      end

      event :failed_commits_validation do
        transition any => :failed_commits_validation
      end

      event :waiting_for_merging do
        transition any => :waiting_for_merging
      end

      event :merging_failed do
        transition any => :merging_failed
      end

      event :completed do
        transition any => :completed
      end

      event :failed do
        transition any => :failed
      end

      event :reject do
        transition any => :rejected
      end

      event :cancel do
        transition any => :canceled
      end
    end

    def in_ci_pipeline?
      ci_pipeline_run? || ci_pipeline_running? || ci_pipeline_verification? || ci_pipeline_verifying?
    end

    def new_task_type
      if ci_pipeline_run?
        :run
      elsif ci_pipeline_verification? || ci_pipeline_verifying?
        :verify
      elsif ci_pipeline_canceling?
        :abort
      else
        false
      end
    end

    def update_status(task)
      Rails.logger.error("----------Shipit::PredictiveBuild#update_status task.status = #{task.status}" )
      Rails.logger.error("----------Shipit::PredictiveBuild#update_status task.predictive_task_type = #{task.predictive_task_type}" )
      task_status = task.status.to_sym
      predictive_task_type = task.predictive_task_type.to_sym

      task_failed if task_status != :running && task_status != :pending && task_status != :success

      if predictive_task_type == :run
        ci_pipeline_running       if task_status == :running || task_status == :pending
        ci_pipeline_verification  if task_status == :success
      elsif predictive_task_type == :verify
        ci_pipeline_verifying     if task_status == :running || task_status == :pending
        ci_pipeline_verified      if task_status == :success && verifying_job_status?(task, 'SUCCESS')
        task_failed               if task_status == :success && verifying_job_status?(task, 'ABORTED')
      elsif predictive_task_type == :abort
        ci_pipeline_canceling     if task_status == :running || task_status == :pending
        canceled      if task_status == :success
      end
    end

    def update_completed_requests
      predictive_branches.each do |p_branch|
        p_branch.update_completed_requests
      end
    end

    def task_failed
      failed
      predictive_branches.each do |p_branch|
        p_branch.reject_predictive_merge_requests(PredictiveBranch::PIPELINE_TASKS_FAILED)
      end
    end

    def verifying_job_status?(task, status)
      res = false
      task.chunks.each do |chunk|
        if chunk.text.include? "finished with status: #{status}"
          res = true
          break
        end
      end
      res
    end

    def trigger_task(run_now = false)
      predictive_task_type = new_task_type
      return unless predictive_task_type
      stack = predictive_branches.first.stack
      user = Shipit::CommandLineUser.new
      predictive_build_task = with_lock do
        task = predictive_build_tasks.build(
          user_id: user.id,
          stack_id: stack.id,
          predictive_task_type: predictive_task_type,
          allow_concurrency: true
        )
        task.save!
        task
      end
      update_status(predictive_build_task)
      run_now ? predictive_build_task.run_now! : predictive_build_task.enqueue
      predictive_build_task
    end

  end
end
