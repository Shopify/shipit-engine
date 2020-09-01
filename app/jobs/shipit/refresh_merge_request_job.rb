# frozen_string_literal: true
module Shipit
  class RefreshMergeRequestJob < BackgroundJob
    queue_as :default

    def perform(merge_request)
      raise Stack::NotYetSynced if merge_request.stack.commits.blank?

      merge_request.refresh!
      ProcessMergeRequestsJob.perform_later(merge_request.stack)
    end
  end
end
