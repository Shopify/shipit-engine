# frozen_string_literal: true

module Shipit
  class Pipeline < Record
    include Redis::Objects
    lock :sync, timeout:60, expiration: 60

    has_many :stacks
    has_many :merge_requests, through: :stacks
    has_many :predictive_builds

    MERGE_MODE_DRY_RUN = 'dryrun'
    MERGE_MODE_DEFAULT = 'default'
    MERGE_MODE_SINGLE = 'single'
    MERGE_MODE_EMERGENCY = 'emergency'

    MERGE_MODES = %w(emergency default single).freeze
    MERGE_SINGLE_MODES = %w(emergency single).freeze
    MERGE_SINGLE_EMERGENCY = %w(emergency).freeze


    # merge_requests
    def release_candidates(mode)
      update_rejected_stacks(mode)
      stacks = mergeable_stacks(mode)
      # Find root merge_requests candidates
      merge_requests = MergeRequest.where(stack: stacks).to_be_merged.mode(mode)
      merge_requests = remove_invalid_merge_requests(merge_requests, mode)

      # Reject candidates due to issues WITH their associated merge_requests
      valid_with = valid_with_merge_requests(merge_requests, mode)

      candidates = []
      merge_requests.each do |merge_request|
        is_rejected = false
        merge_request.with_merge_requests.each do |with_mr|
          is_rejected = true if !valid_with.include? with_mr
        end

        if is_rejected
          merge_request.reject!('with_merge_request_issue')
          msg = <<~MSG
            Failed to process your request due to connected pull request issue.
          MSG
          merge_request.with_merge_requests.each do |with_mr|
            with_mr.reject!('with_merge_request_issue')
            Shipit.github.api.add_comment(with_mr.stack.repository.full_name, with_mr.number, msg)
          end
          Shipit.github.api.add_comment(merge_request.stack.repository.full_name, merge_request.number, msg)
        end

        candidates << merge_request unless is_rejected
      end

      candidates
    end

    def update_rejected_stacks(mode)
      stacks = unmergeable_stacks(mode)
      merge_requests = MergeRequest.where(stack: stacks).to_be_merged.mode(mode)
      merge_requests.each do |merge_request|
        msg = "The repository does not allow merges (#{merge_request.stack.not_mergeable_reason(mode)}). \nIt's typically due to sequential CD failures. \nPlease see the [Shipit documentation - Repository does not allow merges.](https://myvcita.atlassian.net/wiki/spaces/IT/pages/2174976098/Shipit+Troubleshooting+Guide#The-repository-does-not-allow-merges%2Fdeployment-failed) to release the situation or try again later."
        Shipit.github.api.add_comment(merge_request.stack.repository.full_name, merge_request.number, msg) if msg
        merge_request.reject!("not_mergeable")
      end
    end

    def unmergeable_stacks(mode)
      stacks.select{ |s|  !s.allows_merges?(mode) }
    end

    def mergeable_stacks(mode)
      stacks.select{ |s|  s.allows_merges?(mode) }
    end

    def build_in_progress
      predictive_builds.where(status: Shipit::PredictiveBuild::WIP_STATUSES).first
    end

    def stats
      info = {
        pipeline: nil,
        merge_queue: {},
        unmergeable_stacks: unmergeable_stacks(MERGE_MODE_DEFAULT)
      }
      wip = build_in_progress
      if wip
        info[:pipeline] = {
          id: wip.id,
          repos: {},
          tasks: []
        }

        wip.ci_jobs_statuses.each do |cjs|
          info[:pipeline][:tasks] << {name: cjs.name, status: cjs.status, link: cjs.link}
        end

        wip.predictive_branches.each do |p_branch|
          prs = []
          tasks = []
          name = p_branch.stack.repository.full_name
          p_branch.predictive_merge_requests.each do |pmr|
            prs << "/#{name}/pull/#{pmr.merge_request.number}"
          end

          p_branch.ci_jobs_statuses.each do |cjs|
            tasks << {name: cjs.name, status: cjs.status, link: cjs.link}
          end

          info[:pipeline][:repos][name] = { prs: prs, tasks: tasks }
        end
      end

      stacks.each do |stack|
        stack.merge_requests.pending.each do |mr|
          unless mr.predictive_merge_request.waiting.any?
            name = stack.repository.full_name
            info[:merge_queue][name] = [] unless info[:merge_queue][name].present?
            info[:merge_queue][name] << "/#{name}/pull/#{mr.number}"
          end
        end
      end

      info
    end

    def remove_invalid_merge_requests(merge_requests, mode)
      stacks = mergeable_stacks(mode)
      return [] unless stacks

      final_merge_requests = []

      merge_requests.each do |merge_request|
        merge_request.refresh!
        merge_request.reject_unless_mergeable!
        if merge_request.rejected?
          msg = "Pull request was rejected"
          msg = "#{msg} due to #{merge_request.rejection_reason}" if merge_request.rejection_reason
          Shipit.github.api.add_comment(merge_request.stack.repository.full_name, merge_request.number, msg)
        end
        merge_request.cancel! if merge_request.closed?
        merge_request.revalidate! if merge_request.need_revalidation?
      end

      merge_requests.select(&:pending?).each do |merge_request|
        merge_request.refresh!

        if !merge_request.not_mergeable_yet? && merge_request.all_status_checks_passed?
          final_merge_requests << merge_request
        else
          msg = ""
          msg = "Pull request is not mergeable yet. \nIt's typically due to one of the following reasons:\n* Github has not checked the mergeability of your PR yet: Just try again.\n*Your PR contains conflicts: Please fix the conflicts listed below and /shipit again your PR.\n* Shipit doesn't have permissions to your repository: Contact Devops team.\n For more informations please check the [Shipit documentation - Pull request is not mergeable.](https://myvcita.atlassian.net/wiki/spaces/IT/pages/2174976098/Shipit+Troubleshooting+Guide#Pull-request-is-not-mergeable-yet)." if merge_request.not_mergeable_yet?
          msg = "#{msg} Not all status checks passed. Please try again later." unless merge_request.all_status_checks_passed?
          merge_request.reject!("not_mergeable")
          Shipit.github.api.add_comment(merge_request.stack.repository.full_name, merge_request.number, msg) if msg
        end
      end

      final_merge_requests
    end

    def valid_with_merge_requests(merge_requests, mode)
      with_merge_requests = []

      merge_requests.each do |merge_request|
        with_merge_requests = with_merge_requests | merge_request.with_merge_requests # Array unique
      end

      with_merge_requests = with_merge_requests.uniq
      remove_invalid_merge_requests(with_merge_requests, mode)
    end

    def self.schedule_predictive_build
      Pipeline.find_each do |pipeline|
        ProcessPipelineBuildJob.perform_later(pipeline)
      end
    end
  end
end
