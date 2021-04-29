# frozen_string_literal: true

module Shipit
  class PredictiveBuild < Record
    belongs_to :pipeline
    has_many :predictive_build_tasks
    has_many :predictive_branches
    has_many :ci_jobs_statuses

    WAITING_STATUSES = %w(pending).freeze
    WIP_STATUSES = %w(pending branched tasks_running tasks_completed waiting_for_merging failed_commits_validation).freeze

    state_machine :status, initial: :pending do
      state :pending
      state :branched
      state :tasks_running
      state :tasks_completed
      state :failed_commits_validation
      state :waiting_for_merging
      state :merging_failed
      state :completed
      state :failed
      state :rejected
      state :canceled

      event :branched do
        transition any => :branched
      end

      event :tasks_running do
        transition any => :tasks_running
      end

      event :tasks_completed do
        transition any => :tasks_completed
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

    state_machine :ci_stack_status, initial: :ci_stack_pending do
      state :ci_stack_pending
      state :ci_stack_running
      state :ci_stack_completed
      state :ci_stack_failed
      state :ci_stack_rejected
      state :ci_stack_canceled

      event :ci_stack_pending do
        transition any => :ci_stack_pending
      end
      event :ci_stack_running do
        transition any => :ci_stack_running
      end
      event :ci_stack_completed do
        transition any => :ci_stack_completed
      end
      event :ci_stack_failed do
        transition any => :ci_stack_failed
      end
      event :ci_stack_rejected do
        transition any => :ci_stack_rejected
      end
      event :ci_stack_canceled do
        transition any => :ci_stack_canceled
      end
    end

    state_machine :ci_pipeline_status, initial: :ci_pipeline_pending do
      state :ci_pipeline_pending
      state :ci_pipeline_running
      state :ci_pipeline_verification
      state :ci_pipeline_verifying
      state :ci_pipeline_completed
      state :ci_pipeline_failed
      state :ci_pipeline_rejected
      state :ci_pipeline_canceling
      state :ci_pipeline_canceled

      event :ci_pipeline_pending do
        transition any => :ci_pipeline_pending
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
      event :ci_pipeline_completed do
        transition any => :ci_pipeline_completed
      end
      event :ci_pipeline_failed do
        transition any => :ci_pipeline_failed
      end
      event :ci_pipeline_rejected do
        transition any => :ci_pipeline_rejected
      end
      event :ci_pipeline_canceling do
        transition any => :ci_pipeline_canceling
      end
      event :ci_pipeline_canceled do
        transition any => :ci_pipeline_canceled
      end
    end

    def build_failed?
      ci_stack_tasks_failed? || ci_pipeline_tasks_failed?
    end

    def ci_stack_tasks_failed?
      ci_stack_failed? || ci_stack_rejected? || ci_stack_canceled?
    end

    def ci_stack_tasks_running?
      ci_stack_running? || ci_stack_pending?
    end

    def ci_pipeline_tasks_failed?
      ci_pipeline_failed? || ci_pipeline_rejected? || ci_pipeline_canceled?
    end

    def ci_pipeline_tasks_running?
      ci_pipeline_pending? || ci_pipeline_running? || ci_pipeline_verification? || ci_pipeline_verifying?
    end

    def tasks_completed?
      ci_pipeline_completed? && ci_stack_completed?
    end

    def new_pipeline_task_type
      if ci_pipeline_pending?
        :run
      elsif ci_pipeline_verification? || ci_pipeline_verifying?
        :verify
      elsif ci_pipeline_canceling?
        :abort
      else
        false
      end
    end

    def in_emergency_mode?
      mode == Pipeline::MERGE_MODE_EMERGENCY
    end

    def update_status(task)
      pipeline_task_status = task.status.to_sym
      predictive_task_type = task.predictive_task_type.to_sym

      status, jobs, no_match_message = parse_task_output(task)
      upsert_ci_job_statuses(jobs)

      pipeline_tasks_cache_key = "PredictiveBranch::update_status_#{id}"
      if no_match_message
        Shipit.redis.incr(pipeline_tasks_cache_key)
        Shipit.redis.get(pipeline_tasks_cache_key).to_i > 2
        pipeline_task_status = :failed
      else
        Shipit.redis.del(pipeline_tasks_cache_key) if Shipit.redis.get(pipeline_tasks_cache_key).present?
      end

      return pipeline_task_failed unless [:success, :pending, :running].include? pipeline_task_status

      if predictive_task_type == :run
        ci_pipeline_running       if pipeline_task_status == :running || pipeline_task_status == :pending
        ci_pipeline_verification  if pipeline_task_status == :success
      elsif predictive_task_type == :verify
        ci_pipeline_verifying     if pipeline_task_status == :running || pipeline_task_status == :pending || status == :running
        ci_pipeline_completed     if pipeline_task_status == :success && status == :success
        pipeline_task_failed      if pipeline_task_status == :success && status == :aborted
      elsif predictive_task_type == :abort
        ci_pipeline_canceling     if pipeline_task_status == :running || pipeline_task_status == :pending
        canceled                  if pipeline_task_status == :success
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
          Shipit::CiJobsStatus.create!(predictive_build_id: self.id,
                                       name: params[:job_name],
                                       status: params[:status].downcase.to_sym,
                                       link: params[:link])
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

    def update_completed_requests
      predictive_branches.each do |p_branch|
        p_branch.update_completed_requests
      end
    end

    def pipeline_task_failed
      ci_pipeline_failed
      build_failed
    end

    def build_failed
      aborting_tasks(true, PredictiveBranch::PIPELINE_TASKS_FAILED)
      failed
    end

    def aborting_tasks(is_failed, reject_reason)
      if ci_pipeline_tasks_running?
        ci_pipeline_canceling
        trigger_pipeline_tasks(true) if predictive_branches.any?
      end

      predictive_branches.each do |p_branch|
        if ci_stack_tasks_running? && p_branch.tasks_in_progress? && !p_branch.tasks_canceling?
          p_branch.tasks_canceling
          p_branch.trigger_task(true)
        end

        if is_failed && (ci_pipeline_failed? || p_branch.failed?)
          p_branch.reject_predictive_merge_requests(reject_reason)
        else
          p_branch.cancel_predictive_merge_requests(reject_reason)
        end
      end
    end

    def set_ci_comments
      comment = []
      comment << "**CI ##{id} is now in progress for #{pipeline.environment}**"
      comment << ""
      predictive_branches.each do |predictive_branch|
        key = predictive_branch.stack.repository.full_name
        comment << "**#{key}**"
        predictive_branch.predictive_merge_requests.each do |predictive_merge_request|
          link = "/#{key}/pull/#{predictive_merge_request.merge_request.number}"
          comment << '* [' + link + '](' + link + ')'
        end
        comment << ""
      end
      msg = <<~MSG
        #{comment.join("\n")}
      MSG
      predictive_branches.each do |p_branch|
        p_branch.set_comment_to_related_merge_requests(msg)
      end
    end

    def trigger_tasks(run_now = false)
      build_failed unless predictive_branches.any?
      # TODO: removing ci_pipeline_completed in all cases and do it just in case of emergency
      # ci_pipeline_completed if in_emergency_mode? # In case of emergency, we are skipping pipeline tasks
      ci_pipeline_completed # TODO: disabling automation tasks - to remove later
      trigger_pipeline_tasks(run_now)
      trigger_stack_tasks(run_now)
    end

    def trigger_pipeline_tasks(run_now = false)
      predictive_task_type = new_pipeline_task_type
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

    def trigger_stack_tasks(run_now = false)
      p_branches = { running: [], stopped: [], completed: [] }
      predictive_branches.each do |p_branch|
        if p_branch.tasks_in_progress?
          p_branch.trigger_task(run_now)
          p_branches[:running] << p_branch
        elsif p_branch.branch_failed?
          p_branches[:stopped] << p_branch
        elsif p_branch.completed?
          p_branches[:completed] << p_branch
        end
      end

      if p_branches[:running].size + p_branches[:completed].size != predictive_branches.size
        ci_stack_failed
        aborting_tasks(false, PredictiveBranch::STACK_TASKS_FAILED)
      elsif p_branches[:completed].any? && p_branches[:completed].size == predictive_branches.size
        ci_stack_completed
      else
        ci_stack_running
      end
    end

  end
end
