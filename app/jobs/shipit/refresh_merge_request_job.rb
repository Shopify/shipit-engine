# frozen_string_literal: true

module Shipit
  class RefreshMergeRequestJob < BackgroundJob
    queue_as :default

    def perform(merge_request)
      merge_request.refresh!
      ProcessMergeRequestsJob.perform_later(merge_request.stack)
    end
  end
end
