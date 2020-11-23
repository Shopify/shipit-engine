# frozen_string_literal: true
module Shipit
  class ProcessPipelineIntegrationJob < BackgroundJob
    unique :while_executing, runtime_lock_ttl: 3.hours, on_conflict: :log
    timeout 3.hours
    queue_as :pipeline

    # Create a new child Stack
    # Disable merge queue on child

    def perform(pipeline)
      # Create a deployment

      # Find all merge requests
      # Build Predictive branches
      # Run tasks
      # verify nothing changed in Merge requests, lock on stacks of pipeline


      merge_requests = stack.merge_requests.to_be_merged.to_a
      merge_requests.each do |merge_request|
        merge_request.refresh!
        merge_request.reject_unless_mergeable!
        merge_request.cancel! if merge_request.closed?
        merge_request.revalidate! if merge_request.need_revalidation?
      end

      return false unless stack.allows_merges?
      # TODO: Exist if

      merge_requests.select(&:pending?).each do |merge_request|
        merge_request.refresh!
        next unless merge_request.all_status_checks_passed?
        begin
          merge_request.merge!
        rescue MergeRequest::NotReady
          ProcessMergeRequestsJob.set(wait: 10.seconds).perform_later(stack)
          return false
        end
      end
    end

    private

    def predictive_branch(pipeline)

    end

  end
end
