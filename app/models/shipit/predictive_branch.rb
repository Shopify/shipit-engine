# frozen_string_literal: true

module Shipit
  class PredictiveBranch < Record
    belongs_to :predictive_build
    belongs_to :stack
    has_many :predictive_branch_tasks
    has_many :predictive_merge_requests
    belongs_to :stack_commit, class_name: 'Shipit::Commit'

    STACK_TASKS_FAILED = 'stack_tasks_failed'
    PIPELINE_TASKS_FAILED = 'pipeline_tasks_failed'
    COMMIT_VALIDATION_FAILED = 'commit_validation_failed'
    MERGE_PREDICTIVE_TO_STACK_FAILED = 'merge_predictive_to_stack_failed'
    MERGE_MR_TO_PREDICTIVE_FAILED = 'merge_mr_to_predictive_failed'
    MR_MERGED_TO_PREDICTIVE = 'mr_merged_to_predictive'

    REJECTION_OPTIONS = %w(stack_tasks_failed pipeline_tasks_failed merged_failed).freeze
    WAITING_STATUSES = %w(pending).freeze
    WIP_STATUSES = %w(pending tasks_running tasks_verification).freeze

    state_machine :status, initial: :pending do
      state :pending
      state :tasks_running
      state :tasks_verification
      state :tasks_verifying
      state :tasks_canceling
      state :tasks_canceled
      state :failed
      state :completed

      event :tasks_running do
        transition any => :tasks_running
      end

      event :tasks_verification do
        transition any => :tasks_verification
      end

      event :tasks_verifying do
        transition any => :tasks_verifying
      end

      event :tasks_canceling do
        transition any => :tasks_canceling
      end

      event :tasks_canceled do
        transition any => :tasks_canceled
      end

      event :completed do
        transition any => :completed
      end

      event :failed do
        transition any => :failed
      end

    end

    def tasks_in_progress?
      pending? || tasks_running? || tasks_verification? || tasks_verifying? || tasks_canceling?
    end

    def branch_failed?
      tasks_canceled? || failed?
    end

    def new_task_type
      if pending?
        :run
      elsif tasks_verification? || tasks_verifying?
        :verify
      elsif tasks_canceling?
        :abort
      else
        false
      end
    end

    def update_status(task)
      task_status = task.status.to_sym
      predictive_task_type = task.predictive_task_type.to_sym

      task_failed if task_status != :running && task_status != :pending && task_status != :success

      if predictive_task_type == :run
        tasks_running       if task_status == :running || task_status == :pending
        tasks_verification  if task_status == :success
      elsif predictive_task_type == :verify
        tasks_verifying     if task_status == :running || task_status == :pending
        completed           if task_status == :success && verifying_job_status?(task, 'SUCCESS')
        task_failed         if task_status == :success && verifying_job_status?(task, 'ABORTED')
      elsif predictive_task_type == :abort
        tasks_canceling     if task_status == :running || task_status == :pending
        tasks_canceled      if task_status == :success
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
      user = Shipit::CommandLineUser.new
      predictive_branch_task = with_lock do
        task = predictive_branch_tasks.build(
          user_id: user.id,
          stack_id: stack.id,
          predictive_task_type: predictive_task_type,
          allow_concurrency: true
        )
        task.save!
        task
      end
      update_status(predictive_branch_task)
      run_now ? predictive_branch_task.run_now! : predictive_branch_task.enqueue
      predictive_branch_task
    end

    def task_failed
      failed
      reject_predictive_merge_requests(STACK_TASKS_FAILED)
    end

    def cancel_predictive_merge_requests
      predictive_merge_requests.waiting.each do |pmr|
        msg = <<~MSG
          Pull request build attempt was canceled as part of branch '#{branch}' due to emergency build.
        MSG
        pmr.cancel(msg)
      end
    end

    def reject_predictive_merge_requests(reject_reason)
      predictive_merge_requests.waiting.each do |pmr|
        pmr.reject(comment_msg(reject_reason))
      end
      delete_closed_branch(stack.github_repo_name, base: branch)
    end

    def comment_msg(step)
      case step
      when PIPELINE_TASKS_FAILED, STACK_TASKS_FAILED
        msg = "Failed to process your request due to CI failures"
      when COMMIT_VALIDATION_FAILED
        msg = 'Someone pushed changes, we had to stop what we\'re doing and start over.'
      when MERGE_PREDICTIVE_TO_STACK_FAILED
        msg = "Failed to merge predictive branch to #{branch}"
      when MERGE_MR_TO_PREDICTIVE_FAILED
        msg = "Failed to merge MergeRequest to predictive branch"
      when MR_MERGED_TO_PREDICTIVE
        msg = "MergeRequest merged to branch #{stack.branch}"
      else
        return false
      end
      <<~MSG
        #{msg}
      MSG
    end

    def update_completed_requests
      predictive_merge_requests.waiting.each do |pmr|
        delete_closed_branch(pmr.merge_request.stack.github_repo_name, pmr.merge_request.branch)
        pmr.merge_request.complete!
        pmr.merge(comment_msg(MR_MERGED_TO_PREDICTIVE))
      end
      delete_closed_branch(stack.github_repo_name, base: branch)

      predictive_merge_requests.blocked.each do |pmr|
        pmr.merge_request.reject!('merge_conflict')
        pmr.reject(comment_msg(MERGE_PREDICTIVE_TO_STACK_FAILED))
      end
    end

    def delete_closed_branch(repo_name, branch_name)
      begin
        if Shipit.github.api.pull_requests(repo_name, base: branch_name).empty?
          Shipit.github.api.delete_branch(repo_name, branch_name)
        end
      rescue Octokit::UnprocessableEntity
        # branch was already deleted somehow
      end
    end

  end
end
