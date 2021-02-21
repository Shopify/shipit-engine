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

    MERGE_MODES = %w(emergency single default).freeze
    MERGE_SINGLE_MODES = %w(emergency single).freeze
    MERGE_SINGLE_EMERGENCY = %w(emergency).freeze


    # merge_requests
    def release_candidates(stacks, mode)
      # Find root merge_requests candidates
      merge_requests = MergeRequest.where(stack: stacks).to_be_merged.mode(mode)
      merge_requests = remove_invalid_merge_requests(merge_requests, mode)

      # Reject candidates due to issues WITH their associated merge_requests
      valid_with = valid_with_merge_requests(merge_requests, mode)

      merge_requests = merge_requests.select { |merge_request|
        merge_request.with_merge_requests.each do |with_mr|
          if !valid_with.include? with_mr
            # TODO Add comment rejection reason on MR
            # merge_request.reject!('with_merge_request_issue')
            return false
          end
        end

        true
      }

      merge_requests
    end

    def mergeable_stacks(mode)
      stacks.select{ |s|  s.allows_merges?(mode) }
    end

    def stats
      info = {
        pipeline: nil,
        merge_queue: {}
      }
      wip = predictive_builds.where(status: Shipit::PredictiveBuild::WIP_STATUSES).first
      if wip
        info[:pipeline] = {
          id: wip.id,
          repos: {}
        }
        wip.predictive_branches.each do |p_branch|
          prs = []
          tasks = []
          name = p_branch.stack.repository.full_name
          p_branch.predictive_merge_requests.each do |pmr|
            prs << "/#{name}/pulls/#{pmr.merge_request.number}"
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
            info[:merge_queue][name] << "/#{name}/pulls/#{mr.number}"
          end
        end
      end

      info
    end

    private

    def remove_invalid_merge_requests(merge_requests, mode)
      stacks = mergeable_stacks(mode)
      return [] unless stacks

      final_merge_requests = []

      merge_requests.each do |merge_request|
        merge_request.refresh!
        merge_request.reject_unless_mergeable!
        merge_request.cancel! if merge_request.closed?
        merge_request.revalidate! if merge_request.need_revalidation?
      end

      merge_requests.select(&:pending?).each do |merge_request|
        merge_request.refresh!

        if !merge_request.not_mergeable_yet? && merge_request.all_status_checks_passed?
          final_merge_requests << merge_request
        else
          # Todo: Count how long its been queue / Attempts
          #   Auto reject merge_request + comment after a while
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
