# frozen_string_literal: true
module Shipit
  class ProcessPipelineBuildJob < BackgroundJob
    unique :while_executing, runtime_lock_ttl: 3.hours, on_conflict: :log
    timeout 3.hours
    queue_as :pipeline

    # The process handle one batch at a time
    #   if a batch fail, we reject the corresponding MergeRequests according to the selected mode (Emergency, Single & Default)
    #     Emergency/Single: All MergeRequests
    #     Default:
    #         Preparation: Individual
    #         Stack CI: Stack's
    #         Pipeline CI: All
    def perform(pipeline, predictive_branch = "PREDICTIVE-BRANCH-#{pipeline}")
      stacks = mergable_stacks(pipeline)
      return true unless stacks

      predictive_release = PredictiveBuild.create(pipeline: pipeline)

      Pipeline::MERGE_MODES.each do |mode|
        # Release - is a set of merge-requests
        candidates = pipeline.release_candidates(stacks, mode)
        next unless candidates

        # Predictive branch
        limit = MERGE_SINGLE_MODES.include?(mode) ? 1 : nil
        final_stacks, final_candidates = create_predictive_branch(predictive_branch, candidates, limit)
        if final_candidates.length < candidates.length && limit > final_candidates
          # TODO: Notify PullRequest about out attempt
          # Reject merge_request
        end


        # Tasks Per Stack & reject
        # Tasks Pipeline & reject
        # Lock
        #   Validate merge-requests for no changes
        #   Validate mergeable FF!
        #   Merge predictive branch FF!
        # UnLock

      end
    end

    # TODO Refactor to stack predictive merge
    # Merge one merge_request at a time, include its WITH association
    #   Once a merge_request cannot be merged, the process start over this time without the faulty merge_request
    # The process will exist once the limit has reached or all merge_requests have been processed
    def create_predictive_branch(predictive_branch, merge_requests, limit = nil)

      # Sum our stacks
      stacks = []
      stack_metadata = {} # TODO refactor
      tmp_merge_requests = merge_requests
      loop do
        break unless tmp_merge_requests
        stack = tmp_merge_requests.pop
        tmp_merge_requests << tmp_merge_requests.with_merge_requests if tmp_merge_requests.with_merge_requests
        if !stacks.include? stack
          stacks << stack
          stack_metadata[merge_request.stack][:commands] = Commands.for(stack)
        end
      end

      # Work within a tmp dir
      #   TODO work with git cache folder
      merged_to_predictive_branch = []
      predictive_stacks = []
      Dir.mktmpdir do |dir|
        # Clone our repos into their own folder - $dir/owner/repo-name/
        stacks.each do |stack|
          # Clone repo
          clone = stack_metadata[stack][:commands].git_clone(stack.repo_git_url, stack.github_repo_name, branch: stack.branch, env: commands.env, chdir: dir)
          clone.run!
          stack_metadata[stack][:dir] = File.join(dir, stack.github_repo_name)
        end

        # Checkout fresh copy of our to-be-merged branches
        merge_requests.each do |merge_request|
          merge_request.with_all do |mr|
            checkout_fresh_copy(commands: stack_metadata[mr.stack][:commands], branch: mr.branch, chdir: stack_metadata[mr.stack][:dir])
          end
        end

        # Merge the merge_requests one at a time, including their WITH companions
        #   In case and we fail to do so, we start over this time without the fault merge_request
        begin
          # Checkout fresh copy of our predictive branch
          merged_to_predictive_branch = []
          predictive_stacks = []
          merge_request = nil
          create_local_predictive_branch(predictive_branch: predictive_branch, stacks: stacks, stack_metadata: stack_metadata)

          # Merge one layer at a time
          merge_requests.each do |merge_request|
            merge_request.with_all do |mr|
              # Checkout the branch we're about to merge from
              git_checkout(commands: stack_metadata[mr.stack][:commands], branch: mr.branch, chdir: stack_metadata[mr.stack][:dir])
              git_reset(commands: stack_metadata[mr.stack][:commands], to: mr.branch, chdir: stack_metadata[mr.stack][:dir])

              # Checkout predictive branch
              git_checkout(commands: stack_metadata[mr.stack][:commands], branch: mr.stack.branch, chdir: stack_metadata[mr.stack][:dir])

              # Merge
              git_merge_as_pr(commands: stack_metadata[mr.stack][:commands], merge_request: mr, chdir: stack_metadata[mr.stack][:dir])

              predictive_stacks << mr.stack unless predictive_stacks.include? mr.stack
            end
            merged_to_predictive_branch << merge_request

            if limit <= merged_to_predictive_branch.length
              push_predictive_branch(predictive_branch: predictive_branch, stacks: stacks, stack_metadata: stack_metadata)
              return predictive_stacks, merged_to_predictive_branch
            end
          end
        rescue
          # In case and something goes wrong, start over, this time without the faulty merge_request
          merge_requests.delete(merge_request)
          retry
        end
      end

      push_predictive_branch(predictive_branch: predictive_branch, stacks: stacks, stack_metadata: stack_metadata)
      return predictive_stacks, merged_to_predictive_branch
    end

    private

    def with_all(merge_request)
      [merge_request] + merge_request.with_merge_requests
    end

    #
    # TODO refactor private functions,
    #   Probably group into some sort of a Git utility/client or PipelineCommands similar to StackCommands
    #

    def push_predictive_branch(predictive_branch:, stacks: stacks, stack_metadata: )
      stacks.each do |stack|
        git_checkout(commands: stack_metadata[stack][:commands], branch: predictive_branch, chdir: stack_metadata[stack][:dir])
        stack_metadata[stack][:commands].git('push', '-f', branch, chdir: stack_metadata[stack][:dir], env: stack_metadata[stack][:commands].env).run!
      end
    end

    def create_local_predictive_branch(predictive_branch:, stacks: stacks, stack_metadata: )
      stacks.each do |stack|
        # Create a predictive branch
        git_checkout(commands: stack_metadata[stack][:commands], branch: predictive_branch, chdir: stack_metadata[stack][:dir])
        git_set_upstream(commands: stack_metadata[stack][:commands], branch: predictive_branch, chdir: stack_metadata[stack][:dir])
        # Reset to Stack's branch
        git_reset(commands: stack_metadata[stack][:commands], to: stack.branch, chdir: stack_metadata[stack][:dir])
      end
    end

    def git_merge_as_pr(commands:, merge_request:, chdir: )
      commands.git('merge', '--no-ff', '-m', "Merge pull request #{merge_request.number} from vcita/#{merge_request.branch}", merge_request.branch, chdir: chdir, env: commands.env).run!
    end

    def checkout_fresh_copy(commands:, branch: , chdir:)
      git_checkout(commands: commands, branch: branch, chdir: chdir)
      git_set_upstream(commands: commands, branch: branch, chdir: chdir)
      git_reset_origin(commands: commands, branch: branch, chdir: chdir)
    end

    def git_reset_origin(commands:, branch: , chdir:)
      commands.git('fetch', 'origin', chdir: chdir, env: commands.env).run!
      git_reset_to_origin(commands: commands, to: branch, chdir: chdir)
    end

    def git_reset(commands:, to: , chdir:)
      commands.git('reset', '--hard', to, chdir: chdir, env: commands.env).run!
      commands.git('reset', 'clean', '-ffdx', chdir: chdir, env: commands.env).run!
    end

    def git_reset_to_origin(commands:, to:, chdir:)
      git_reset(commands: commands, to: "origin/#{to}", chdir: chdir)
    end

    def git_branch(commands:, chdir:)
      commands.git('rev-parse', '--abbrev-ref', 'HEAD', chdir: chdir, env: commands.env).run!.trim
    end

    def git_set_upstream(commands:, branch: , chdir:)
      commands.git('branch', "--set-upstream-to=origin/#{branch}", branch, chdir: chdir, env: commands.env).run!
    end

    def git_checkout(commands:, branch: , chdir: )
      commands.git('checkout', '-b', branch, chdir: chdir, env: commands.env).run!
    end

    def git_fetched?(commands:, commit:, chdir: )
      git('rev-parse', '--quiet', '--verify', "#{commit.sha}^{commit}", chdir: chdir, env: commands.env)
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
