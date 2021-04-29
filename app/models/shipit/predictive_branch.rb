# frozen_string_literal: true

module Shipit
  class PredictiveBranch < Record
    belongs_to :predictive_build
    belongs_to :stack
    has_many :predictive_branch_tasks
    has_many :predictive_merge_requests
    has_many :ci_jobs_statuses
    belongs_to :stack_commit, class_name: 'Shipit::Commit'

    STACK_TASKS_FAILED = 'stack_tasks_failed'
    PIPELINE_TASKS_FAILED = 'pipeline_tasks_failed'
    COMMIT_VALIDATION_FAILED = 'commit_validation_failed'
    MERGE_PREDICTIVE_TO_STACK_FAILED = 'merge_predictive_to_stack_failed'
    MERGE_MR_TO_PREDICTIVE_FAILED = 'merge_mr_to_predictive_failed'
    MR_MERGED_TO_PREDICTIVE = 'mr_merged_to_predictive'
    CANCELED_DUE_TO_EMERGENCY = 'canceled_due_to_emergency'
    MR_STOPPED = 'mr_stopped'

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

      status, jobs, no_match_message = parse_task_output(task)
      upsert_ci_job_statuses(jobs) unless predictive_task_type == :run

      ci_tasks_cache_key = "PredictiveBranch::update_status_#{id}"
      if no_match_message
        Shipit.redis.incr(ci_tasks_cache_key)
        Shipit.redis.get(ci_tasks_cache_key).to_i > 2
        task_status = :failed
      else
        Shipit.redis.del(ci_tasks_cache_key) if Shipit.redis.get(ci_tasks_cache_key).present?
      end

      return task_failed unless [:success, :pending, :running].include? task_status

      if predictive_task_type == :run
        tasks_running       if task_status == :running || task_status == :pending
        tasks_verification  if task_status == :success
      elsif predictive_task_type == :verify
        tasks_verifying     if task_status == :running || task_status == :pending || status == :running
        completed           if task_status == :success && status == :success
        task_failed         if task_status == :success && status == :aborted
      elsif predictive_task_type == :abort
        tasks_canceling     if task_status == :running || task_status == :pending
        tasks_canceled      if task_status == :success
      end

    end

    def upsert_ci_job_statuses(jobs)
      ci_jobs_statuses.each do |job_status|
        if jobs[job_status.name].present?
          job_status.update_status(jobs[job_status.name][:status].downcase.to_sym)
          jobs.delete(job_status.name)
        end
      end

      if jobs.any?
        jobs.each do |name, params|
          begin
            Shipit::CiJobsStatus.create!(predictive_branch_id: self.id,
                                         name: params[:job_name],
                                         status: params[:status].downcase.to_sym,
                                         link: params[:link])
          rescue
            puts "--------- upsert_ci_job_statuses:: failed to create CiJobsStatus."
            puts "--------- upsert_ci_job_statuses:: predictive_branch_id: #{self.id} ; name: #{params[:job_name]} ; status: #{params[:status]} link: #{params[:link]}"
          end

        end
      end
    end

    def parse_task_output(task)
      no_match_message = false
      jobs = {}
      statuses = {aborted: 0, running: 0, success: 0}
      task.chunks.each do |chunk|
        if chunk.text.include?('job_name:') && chunk.text.include?('link:') && chunk.text.include?('status:')
          cmd = {}
          chunk.text.split(' ').each do |substr|
            substr_arr = substr.split(':')
            cmd[substr_arr.first.to_sym] = substr_arr.last if substr_arr.first.in?(['job_name', 'link', 'status'])
          end
          jobs[cmd[:job_name]] = cmd
          statuses[cmd[:status].downcase.to_sym] += 1 if statuses[cmd[:status].downcase.to_sym].present?
        end
        if chunk.text.include?('No match found')
          no_match_message = true
        end
      end

      return :aborted, jobs, no_match_message if statuses[:aborted] > 0
      return :running, jobs, no_match_message if statuses[:running] > 0
      return :success, jobs, no_match_message if statuses[:success] > 0
      return false, jobs, no_match_message
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

    def cancel_predictive_merge_requests(reject_reason = nil)
      predictive_merge_requests.waiting.each do |pmr|
        pmr.cancel(comment_msg(reject_reason))
      end
    end

    def reject_predictive_merge_requests(reject_reason)
      predictive_merge_requests.waiting.each do |pmr|
        pmr.reject(comment_msg(reject_reason))
      end
      # delete_closed_branch(stack.github_repo_name, branch)
    end

    def additional_failed_information
      return '' if failed?
      failed_branches = []
      predictive_build.predictive_branches.each do |p_build_branch|
        failed_branches << p_build_branch if p_build_branch.failed?
      end
      return '' if failed_branches.empty?
      res = " of: "
      failed_branches.each do |fb|
        name = fb.stack.repository.full_name
        fb.predictive_merge_requests.each do |pmr|
          res = res + " /#{name}/pull/#{pmr.merge_request.number}"
        end
      end
      res
    end

    def comment_msg(step)
      case step
      when PIPELINE_TASKS_FAILED, STACK_TASKS_FAILED
        msg = "Failed to process your request due to CI failures" + additional_failed_information
      when COMMIT_VALIDATION_FAILED
        msg = "Someone pushed changes directly to #{stack.branch} branch, we had to stop what we're doing, please try again later."
      when MERGE_PREDICTIVE_TO_STACK_FAILED
        msg = "Failed to merge predictive branch to #{stack.branch}"
      when MERGE_MR_TO_PREDICTIVE_FAILED
        msg = "Failed to merge pull request to predictive branch"
      when MR_MERGED_TO_PREDICTIVE
        msg = "Pull request merged to branch #{stack.branch}"
      when CANCELED_DUE_TO_EMERGENCY
        msg = "Pull request build attempt was canceled as part of branch '#{branch}' due to emergency build."
      when MR_STOPPED
        msg = "The pipeline process was stopped"
      else
        return false
      end
      <<~MSG
        #{msg}
      MSG
    end

    def update_completed_requests
      predictive_merge_requests.waiting.each do |pmr|
        # delete_closed_branch(pmr.merge_request.stack.github_repo_name, pmr.merge_request.branch)
        pmr.merge_request.complete!
        pmr.merge(comment_msg(MR_MERGED_TO_PREDICTIVE))
      end
      # delete_closed_branch(stack.github_repo_name, branch)

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
      rescue Exception => e
        Rails.logger.error "Can't delete branch. message: #{e.message}"
      end
    end

    def set_comment_to_related_merge_requests(msg)
      predictive_merge_requests.each do |pmr|
        pmr.add_comment(msg)
      end
    end
  end
end
