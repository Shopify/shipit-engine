# frozen_string_literal: true
module Shipit
  class ProcessMergeRequestsJob < BackgroundJob
    include BackgroundJob::Unique
    on_duplicate :drop

    queue_as :default

    def perform(stack)
      return ProcessPipelineBuildJob.perform_later(stack.pipline) if stack.pipline

      merge_requests = stack.merge_requests.to_be_merged.to_a
      merge_requests.each do |merge_request|
        merge_request.refresh!
        merge_request.reject_unless_mergeable!
        merge_request.cancel! if merge_request.closed?
        merge_request.revalidate! if merge_request.need_revalidation?
      end

      return false unless stack.allows_merges?

      merge_requests.root.select(&:pending?).each do |merge_request|
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
  end
end
