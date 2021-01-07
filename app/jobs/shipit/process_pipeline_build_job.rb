# frozen_string_literal: true
module Shipit
  class ProcessPipelineBuildJob < BackgroundJob
    include BackgroundJob::Unique
    on_duplicate :drop
    queue_as :pipeline

    # The process handle one batch at a time
    #   if a batch fail, we reject the corresponding MergeRequests according
    #   to the selected mode (Emergency, Single & Default)
    #     Emergency/Single: All MergeRequests
    #     Default:
    #         Preparation: Individual
    #         Stack CI: Stack's
    #         Pipeline CI: All
    def perform(pipeline)
      predictive_builds = PredictiveBuild.where(pipeline: pipeline).where(status: PredictiveBuild::WIP_STATUSES)

      if predictive_builds.any?
        predictive_build = predictive_builds.last
        if predictive_build.mode != Pipeline::MERGE_MODE_EMERGENCY && emergency_build?(pipeline)
          unless predictive_build.ci_pipeline_canceling?
            abort_running_predictive_build(predictive_build)
          end
        end
      else
        predictive_build = generate_predictive_build(pipeline)
        unless predictive_build
          Shipit::ProcessPipelineBuildJob.set(wait: 1.minute).perform_later(pipeline)
          return true
        end
      end

      case predictive_build.status.to_sym
      when :pending
        # Something went wrong
        predictive_build.cancel
        Shipit::ProcessPipelineBuildJob.perform_later(pipeline)
      when :ci_stack_tasks
        run_stacks_tasks(pipeline, predictive_build)
      when :ci_pipeline_run, :ci_pipeline_running, :ci_pipeline_verification,
            :ci_pipeline_verifying, :ci_pipeline_canceling
        run_pipeline_tasks(pipeline, predictive_build)
      when :ci_pipeline_verified
        merging_process(predictive_build)
      else
        Shipit::ProcessPipelineBuildJob.set(wait: 1.minute).perform_later(pipeline)
      end
    end

    def merging_process(predictive_build)
      commits_validation(predictive_build)
      merge_build(predictive_build) if predictive_build.waiting_for_merging?
      predictive_build.update_completed_requests if predictive_build.completed?
    end

    def merge_build(predictive_build)
      Dir.mktmpdir do |dir|
        stack_commands = merge_predictive_branches(predictive_build, dir)
        push_build(predictive_build, stack_commands) unless predictive_build.merging_failed?
      end
      if predictive_build.merging_failed?
        update_failed_build(predictive_build, Shipit::PredictiveBranch::MERGE_PREDICTIVE_TO_STACK_FAILED)
      else
        predictive_build.completed
      end
    end

    def commits_validation(predictive_build)
      predictive_build.predictive_branches.each do |p_branch|
        stack_commit = Shipit::Commit.where(stack_id: p_branch.stack.id, detached: 0).last
        if stack_commit.id != p_branch.stack_commit.id
          predictive_build.failed_commits_validation
          break
        end
        p_branch.predictive_merge_requests.waiting.each do |pmr|
          pmr.merge_request.refresh!
          if pmr.merge_request.head.id != pmr.head.id
            predictive_build.failed_commits_validation
            break
          end
        end
        break if predictive_build.failed_commits_validation?
      end

      if predictive_build.failed_commits_validation?
        update_failed_build(predictive_build, Shipit::PredictiveBranch::COMMIT_VALIDATION_FAILED)
      else
        predictive_build.waiting_for_merging
      end
    end

    def update_failed_build(predictive_build, reject_reason)
      predictive_build.predictive_branches.each do |p_branch|
        p_branch.reject_predictive_merge_requests(reject_reason)
      end
    end

    def abort_running_predictive_build(predictive_build)
      if predictive_build.pending? || predictive_build.ci_stack_tasks?
        predictive_build.cancel
        predictive_build.predictive_branches.each do |p_branch|
          next unless p_branch.pending? || p_branch.tasks_running? ||
            p_branch.tasks_verification? || p_branch.tasks_verifying?
          p_branch.tasks_canceling
          p_branch.trigger_task(true)
          p_branch.cancel_predictive_merge_requests
        end
      elsif predictive_build.in_ci_pipeline?
        predictive_build.ci_pipeline_canceling
        predictive_build.trigger_task(true)
      end

      predictive_build.predictive_branches.each do |p_branch|
        p_branch.cancel_predictive_merge_requests
      end
    end

    def emergency_build?(pipeline)
      stacks = pipeline.mergeable_stacks
      return false unless stacks
      merge_requests = MergeRequest.where(stack: stacks).to_be_merged.mode(Pipeline::MERGE_MODE_EMERGENCY)
      merge_requests.any?
    end

    def generate_predictive_build(pipeline)
      stacks = pipeline.mergeable_stacks
      return false unless stacks

      predictive_build = PredictiveBuild.create(pipeline: pipeline, branch: "PREDICTIVE-BRANCH-:id")
      predictive_build.update(branch: "PREDICTIVE-BRANCH-#{predictive_build.id}")
      predictive_build_mode = nil

      Shipit::Pipeline::MERGE_MODES.each do |mode|
        predictive_build_mode = mode
        candidates = pipeline.release_candidates(stacks, mode)
        next unless candidates

        limit = Shipit::Pipeline::MERGE_SINGLE_MODES.include?(mode) ? 1 : nil
        merged_candidates = create_predictive_branches(predictive_build, candidates, limit)

        break if merged_candidates.any?
      end

      # If no branches are found, we're done!
      if predictive_build.predictive_branches.empty?
        predictive_build.completed
        return predictive_build
      end

      predictive_build.update(mode: predictive_build_mode) if predictive_build_mode != Pipeline::MERGE_MODE_DEFAULT
      predictive_build.stack_tasks
      predictive_build
    end

    def run_stacks_tasks(pipeline, predictive_build)
      p_branches = { running: [], stopped: [], completed: [] }
      predictive_build.predictive_branches.each do |p_branch|
        if p_branch.pending? || p_branch.tasks_running? || p_branch.tasks_verification? ||
            p_branch.tasks_verifying? || p_branch.tasks_canceling?
          p_branch.trigger_task
          p_branches[:running] << p_branch
        elsif p_branch.tasks_canceled? || p_branch.failed?
          p_branches[:stopped] << p_branch
        elsif p_branch.completed?
          p_branches[:completed] << p_branch
        end
      end

      if p_branches[:running].size + p_branches[:completed].size != predictive_build.predictive_branches.size
        predictive_build.ci_pipeline_failed
        abort_running_predictive_build(predictive_build)
        update_failed_build(predictive_build, Shipit::PredictiveBranch::STACK_TASKS_FAILED)
      else
        if p_branches[:completed].any? && p_branches[:completed].size == predictive_build.predictive_branches.size
          predictive_build.pipeline_tasks
        end
        Shipit::ProcessPipelineBuildJob.set(wait: 5.seconds).perform_later(pipeline)
      end
    end

    def run_pipeline_tasks(pipeline, predictive_build)
      predictive_build.trigger_task
      unless predictive_build.completed? || predictive_build.failed? || predictive_build.canceled?
        Shipit::ProcessPipelineBuildJob.set(wait: 5.seconds).perform_later(pipeline)
      end
    end

    # Merge merge_requests into their corresponding predictive-branches
    #   The process will exist once the limit has reached or all merge_requests were processed
    def create_predictive_branches(predictive_build, merge_requests, limit = nil)
      merged_stacks = {}
      merged_to_predictive_branch = []
      rejected_merged_requests = []
      predictive_branches = {}

      Dir.mktmpdir do |dir|
        merge_requests, stack_commands = fetch_and_clone_merge_requests(predictive_build, merge_requests, dir)
        stack_commands = checkout_clean_stack_predictive_branch(predictive_build, stack_commands)

        # Merge one layer at a time, a layer includes the main merge_request and its WITH associations
        #   On failure, try again, this time without the faulty merge_request
        begin
          # Merge
          merge_request = nil
          merge_requests.each do |merge_request|
            # One layer at a time
            merge_request.with_all do |mr|
              mr.refresh!
              unless predictive_branches[mr.stack.id]
                stack_commit = Shipit::Commit.where(stack_id: mr.stack.id, detached: 0).last
                predictive_branches[mr.stack.id] = PredictiveBranch.create(predictive_build: predictive_build,
                                                                           branch: predictive_build.branch,
                                                                           stack: mr.stack,
                                                                           stack_commit: stack_commit)
              end
              stack_commands[mr.stack].git_merge_origin_as_pr(mr.branch, mr.number).run!
              merged_stacks[mr.stack.id] = mr.stack
              PredictiveMergeRequest.create(merge_request: mr,
                                            predictive_branch: predictive_branches[mr.stack.id],
                                            head: mr.head)
            end
            merged_to_predictive_branch << merge_request

            if limit && limit <= merged_to_predictive_branch.length
              push_predictive_branch(stack_commands, merged_stacks)
              return merged_to_predictive_branch
            end
          end
        rescue => error
          merge_request.with_all do |mr|
            rejected_merged_requests << mr
            PredictiveMergeRequest.create(merge_request: mr,
                                          predictive_branch: predictive_branches[mr.stack.id],
                                          head: mr.head,
                                          status: :rejected)
          end

          merge_requests.delete(merge_request)
          merged_stacks = []
          merged_to_predictive_branch = []
          retry unless merge_requests
        end
        push_predictive_branch(stack_commands, merged_stacks)
      end

      return merged_to_predictive_branch
    end

    # Checkout clean predictive branch locally
    def checkout_clean_stack_predictive_branch(predictive_build, stack_commands)
      stack_commands.each do |stack, commands|
        commands.git_checkout(predictive_build.branch).run!
        commands.git_reset("origin/#{stack.branch}").run!
        commands.git_clean.run!
      end

      stack_commands
    end

    # Sum our stacks & Clone our repos into their own folder - dir/organization/repo-name/
    # Fetch fresh copy of our to-be-merged branches
    def fetch_and_clone_merge_requests(predictive_build, merge_requests, dir)
      stack_commands = {}
      merge_requests.each do |merge_request|
        merge_request.with_all do |mr|
          unless stack_commands[mr.stack]
            stack_commands[mr.stack] = Commands.for(predictive_build, mr.stack, File.join(dir, mr.stack.repo_name))
            stack_commands[mr.stack].git_clone(chdir: dir).run!
          end
          stack_commands[mr.stack].git_fetch(mr.branch).run!
        end
      end

      return merge_requests, stack_commands
    end

    # Sum our stacks & Clone our repos into their own folder - dir/organization/repo-name/
    # Fetch fresh copy of our to-be-merged branches
    def merge_predictive_branches(predictive_build, dir)
      stack_commands = {}
      begin
        predictive_build.predictive_branches.each do |p_branch|
          stack_commands[p_branch.stack] = Commands.for(predictive_build,
                                                        p_branch.stack,
                                                        File.join(dir, p_branch.stack.repo_name))
          stack_commands[p_branch.stack].git_clone(chdir: dir).run!
          stack_commands[p_branch.stack].git_fetch(p_branch.branch).run!
          stack_commands[p_branch.stack].git_merge_ff(p_branch.branch).run!
        end
      rescue
        predictive_build.merging_failed
      end

      stack_commands
    end

    def push_build(predictive_build, stack_commands)
      predictive_build.predictive_branches.each do |p_branch|
        stack_commands[p_branch.stack].git_push(true).run!
      end
      stack_commands
    end

    private

    def with_all(merge_request)
      [merge_request] + merge_request.with_merge_requests
    end

    def push_predictive_branch(stack_commands, changed_stacks)
      changed_stacks.each do |key, stack|
        stack_commands[stack].git_push(true).run!
      end
    end
  end
end