# frozen_string_literal: true
module Shipit
  # TODO Refactor: Convert to a Task PredictiveBuild < Task
  class ProcessPipelineBuildJob < BackgroundJob
    unique :while_executing, runtime_lock_ttl: 1.hours, on_conflict: :log
    self.timeout = 1.hours
    queue_as :pipeline

    # The process handle one batch at a time
    #   if a batch fail, we reject the corresponding MergeRequests according to the selected mode (Emergency, Single & Default)
    #     Emergency/Single: All MergeRequests
    #     Default:
    #         Preparation: Individual
    #         Stack CI: Stack's
    #         Pipeline CI: All
    def perform(pipeline)
      stacks = mergable_stacks(pipeline)
      return true unless stacks

      predictive_build = PredictiveBuild.create(pipeline: pipeline, branch: "PREDICTIVE-BRANCH-:id")
      predictive_build.update(branch: "PREDICTIVE-BRANCH-#{predictive_build.id}")

      Pipeline::MERGE_MODES.each do |mode|
        candidates = pipeline.release_candidates(stacks, mode)
        next unless candidates

        # Predictive branch
        limit = MERGE_SINGLE_MODES.include?(mode) ? 1 : nil
    stack_candidates = []
        merged_candidates, merged_stacks = create_predictive_branch(predictive_build, candidates, limit)
        if merged_candidates.length < candidates.length && limit > merged_candidates
          # TODO: Notify PullRequest about out attempt
          # Reject merge_request
        end
        next unless merged_candidates

        # Build the stacks that were changed
        merged_stacks.each do |merged_stack|
          # TODO ?!
          predictive_build.trigger_build_predictive_branch(Shipit::CommandLineUser.new, merged_stack)
        end

        # Wait up to an hour for build process to complete
        iteration = 0
        max_iteration = 60*60  # 1H TODO: github app ci_timeout
        loop do
          break if iteration > max_iteration
          break if predictive_build.predictive_branches.none? { |task| task.(&:active?) }
          sleep(1)
        end
        # TODO: if iteration >= max_iteration timeout reached

        # Remove all candidates that were merged to rejected stacks
        built_stacks = []
        predictive_build.predictive_branches.each do |predictive_branch|
          if predictive_branch.success?
            built_stacks << predictive_branch.stack
          else
            # Stop all running jobs
            predictive_branch.abort! if predictive_branch.active?
          end
        end

        final_candidates = {}
        rejected_candidates = {}
        merged_candidates.each do |merge_request|
          merge_request.with_all do |mr|
            if built_stacks.include? mr.stack
              final_candidates << merge_request
            else
              rejected_candidates << merge_request
            end
          end
        end

        # TODO: Notify rejected_candidates.PullRequest about out attempt

        # Tasks Pipeline & reject
        # final_candidates & built_stacks

        # Lock
        #   Validate merge-requests for no changes
        #   Validate mergeable FF!
        #   Merge predictive branch FF!
        # UnLock

      end
    end

    # Merge merge_requests into their corresponding predictive-branches
    #   The process will exist once the limit has reached or all merge_requests were processed
    def create_predictive_branch(predictive_build, merge_requests, limit = nil)

      merged_stacks = []
      merged_to_predictive_branch = []
      Dir.mktmpdir do |dir|
        # Sum our stacks & Clone our repos into their own folder - dir/organization/repo-name/
        stack_commands = {}
        merge_requests.each do |merge_request|
          merge_request.with_all do |mr|
            next if stack_commands[mr.stack]
            stack_commands[mr.stack] = Commands.for(predictive_build, mr.stack, File.join(dir, mr.stack.repo_name))
            stack_commands[mr.stack].git_clone(chdir: dir).run!
          end
        end

        # Fetch fresh copy of our to-be-merged branches
        merge_requests.each do |merge_request|
          merge_request.with_all do |mr|
            stack_commands[mr.stack].git_fetch(mr.branch).run!
          end
        end

        # Merge one layer at a time, a layer includes the main merge_request and its WITH associations
        #   On failure, try again, this time without the faulty merge_request
        begin
          # Create & Checkout predictive branch locally
          stack_commands.each do |stack, commands|
            commands.git_checkout(predictive_build.branch).run!
            commands.git_reset("origin/#{stack.branch}").run!
            commands.git_clean.run!
          end

          # Merge
          merge_request = nil
          merge_requests.each do |merge_request|
            # One layer at a time
            merge_request.with_all do |mr|
              stack_commands[mr.stack].git_merge_origin_as_pr(mr.branch, mr.number)
            end
            merged_to_predictive_branch << merge_request
            merged_stacks << merge_request.stack unless merged_stacks.include?(merge_request.stack)

            if limit <= merged_to_predictive_branch.length
              push_predictive_branch(stack_commands, merged_stacks)
              return merged_to_predictive_branch, merged_stacks
            end
          end
        rescue
          # In case and something goes wrong, start over, this time without the faulty merge_request
          merge_requests.delete(merge_request)
          retry unless merge_requests
        end

        push_predictive_branch(stack_commands, merged_stacks)
      end

      return merged_to_predictive_branch, merged_stacks
    end

    private

    def with_all(merge_request)
      [merge_request] + merge_request.with_merge_requests
    end

    def push_predictive_branch(stack_commands, changed_stacks)
      changed_stacks.each do |stack|
        stack_commands[stack].git_push(true)
      end
    end

  end
end
=begin
  Step 1: From your project repository, bring in the changes and test.

      git fetch origin
  git checkout -b test_merge_before_approve_pr origin/test_merge_before_approve_pr
  git merge integration
  Step 2: Merge the changes and update on GitHub.

  git checkout integration
  git merge --no-ff test_merge_before_approve_pr -m "Merge pull request #7791 from vcita/test_merge_before_approve_pr"
  git push origin integration
=end
