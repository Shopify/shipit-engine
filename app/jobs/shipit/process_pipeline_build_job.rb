# frozen_string_literal: true
module Shipit
  class ProcessPipelineBuildJob < BackgroundJob
    include BackgroundJob::Unique
    on_duplicate :drop
    queue_as :pipeline

    def lock_key(*args)
      ActiveJob::Arguments.serialize([self.class.name,args.first.id]).join('-')
    end

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
        predictive_build = predictive_builds.first
        if !predictive_build.mode.in?(Pipeline::MERGE_SINGLE_EMERGENCY) && emergency_build?(pipeline) &&
          !predictive_build.ci_pipeline_canceling?
          predictive_build.cancel
          predictive_build.aborting_tasks(false, PredictiveBranch::CANCELED_DUE_TO_EMERGENCY)
          Shipit::ProcessPipelineBuildJob.set(wait: 5.seconds).perform_later(pipeline)
        end
      else
        predictive_build = generate_predictive_build(pipeline)
        return true unless predictive_build
        predictive_build.set_ci_comments
      end

      case predictive_build.status.to_sym
      when :pending # Something went wrong
        predictive_build.cancel
        predictive_build.aborting_tasks(true, PredictiveBranch::PIPELINE_TASKS_FAILED)
      when :branched, :tasks_running
        run_tasks(predictive_build)
      when :tasks_completed, :waiting_for_merging
        merging_process(predictive_build)
      when :failed_commits_validation
        predictive_build.failed
      end
    end

    def merging_process(predictive_build)
      commits_validation(predictive_build) unless predictive_build.waiting_for_merging?
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

    def emergency_build?(pipeline)
      stacks = pipeline.mergeable_stacks(Shipit::Pipeline::MERGE_MODE_EMERGENCY)
      return false unless stacks
      merge_requests = MergeRequest.where(stack: stacks).to_be_merged.emergency_mode
      merge_requests.any?
    end

    def generate_predictive_build(pipeline)
      return false unless pipeline.stacks

      predictive_build = nil
      predictive_build_mode = nil

      Shipit::Pipeline::MERGE_MODES.each do |mode|
        predictive_build_mode = mode
        candidates = pipeline.release_candidates(mode)
        next if !candidates || candidates.empty?

        predictive_build = PredictiveBuild.create(pipeline: pipeline, branch: "PREDICTIVE-BRANCH-:id")
        predictive_build.update(branch: "PREDICTIVE-BRANCH-#{predictive_build.id}")

        limit = Shipit::Pipeline::MERGE_SINGLE_MODES.include?(mode) ? 1 : nil
        merged_candidates = create_predictive_branches(predictive_build, candidates, limit)

        break if merged_candidates.any?
      end
      return false unless predictive_build

      # If no branches are found, we're done!
      if predictive_build.predictive_branches.empty?
        predictive_build.completed
        return predictive_build
      end

      predictive_build.update(mode: predictive_build_mode) if predictive_build_mode != Pipeline::MERGE_MODE_DEFAULT
      predictive_build.branched
      predictive_build
    end

    def run_tasks(predictive_build)
      if predictive_build.build_failed?
        predictive_build.build_failed
        update_failed_build(predictive_build, Shipit::PredictiveBranch::STACK_TASKS_FAILED)
      elsif predictive_build.tasks_completed?
        predictive_build.tasks_completed
      else
        predictive_build.tasks_running
        predictive_build.trigger_tasks
      end
    end

    # Merge merge_requests into their corresponding predictive-branches
    #   The process will exist once the limit has reached or all merge_requests were processed
    def create_predictive_branches(predictive_build, merge_requests, limit = nil)
      merged_stacks = {}
      merged_to_predictive_branch = []
      rejected_merged_requests = []
      predictive_branches = {}
      predictive_merge_requests = []

      Dir.mktmpdir do |dir|
        merge_requests, stack_commands = fetch_and_clone_merge_requests(predictive_build, merge_requests, dir)
        stack_commands = checkout_clean_stack_predictive_branch(predictive_build, stack_commands)

        # Merge one layer at a time, a layer includes the main merge_request and its WITH associations
        #   On failure, try again, this time without the faulty merge_request
        begin
          # Merge
          current_merge_request = nil
          merge_requests.each do |merge_request|
            current_merge_request = merge_request
            # One layer at a time
            merge_request.with_all do |mr|
              mr.refresh!
              unless predictive_branches[mr.stack.id]
                stack_commit = Shipit::Commit.where(stack_id: mr.stack.id, detached: 0).last
                predictive_branches[mr.stack.id] = Shipit::PredictiveBranch.create(predictive_build: predictive_build, branch: predictive_build.branch, stack: mr.stack, stack_commit: stack_commit)
              end
              stack_commands[mr.stack].git_merge_origin_as_pr(mr.branch, mr.number).run!
              merged_stacks[mr.stack.id] = mr.stack
              predictive_merge_requests << Shipit::PredictiveMergeRequest.create(merge_request: mr, predictive_branch: predictive_branches[mr.stack.id], head: mr.head)
            end
            merged_to_predictive_branch << merge_request

            if limit && limit <= merged_to_predictive_branch.length
              push_predictive_branch(stack_commands, merged_stacks)
              return merged_to_predictive_branch
            end
            # current_merge_request = nil
          end
          push_predictive_branch(stack_commands, merged_stacks)
        rescue => error
          puts "ProcessPipelineBuildJob#create_predictive_branches = failed"
          if current_merge_request
            puts "there is a merge request"
            current_merge_request.with_all do |mr|
              puts "Current MR ID= #{mr.id}"
              rejected_merged_requests << mr
              puts "predictive_merge_requests= #{predictive_merge_requests.size}"
              predictive_merge_requests.each do |pmr|
                puts "ProcessPipelineBuildJob#create_predictive_branches Delete PredictiveMergeRequest id=#{pmr.id}"
                Shipit::PredictiveMergeRequest.delete(pmr.id)
              end
              puts "predictive_branches= #{predictive_branches.size}"
              stack_messages = {}
              predictive_branches.each do |key, val|
                stack_messages[val.stack_id] = val.comment_msg(Shipit::PredictiveBranch::PREDICTIVE_BRANCH_CREATION_MERGE_FAILED)
                puts "predictive_branches key= #{key}"
                puts "ProcessPipelineBuildJob#create_predictive_branches Delete PredictiveBranch id=#{val.id}"
                Shipit::PredictiveBranch.delete(val.id)
              end
              puts "ProcessPipelineBuildJob#create_predictive_branches reject! MergeRequest id=#{mr.id}"
              mr.reject!("not_mergeable")
              mr.set_comment(stack_messages[mr.stack_id]) if stack_messages[mr.stack_id]
            end
            current_merge_request.delete(current_merge_request)
          end
        end
      end

      return create_predictive_branches(predictive_build, merge_requests, limit) if rejected_merged_requests.any? && merge_requests.any?
      return merged_to_predictive_branch unless rejected_merged_requests.any?
      []
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
        puts "--------- push_build:: Pushing #{p_branch.branch}"
        stack_commands[p_branch.stack].git_push(true).run!
        puts "--------- push_build:: Getting #{p_branch.stack.branch} last commit sha"
        last_commit_sha = stack_commands[p_branch.stack].git_last_commit(p_branch.stack.branch).run!
        puts "--------- push_build:: last_commit_sha = #{last_commit_sha}"
        if last_commit_sha.present?
          last_commit_sha.slice! "\r\n"
          p_branch.until_commit_sha = last_commit_sha
          puts "--------- push_build:: lGet last commit"
          last_commits = Shipit::Commit.where(sha: last_commit_sha)
          if last_commits.any?
            last_commit = last_commits.first
            puts "--------- push_build:: last_commit.id = #{last_commit.id}" if last_commit.present?
            p_branch.until_commit_id = last_commit.id if last_commit.present?
          end
          p_branch.save!
        end
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
