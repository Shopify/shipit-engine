# frozen_string_literal: true
module Shipit
  class RefreshPullRequestJob < BackgroundJob
    queue_as :default

    def perform(pull_request)
      raise Stack::NotYetSynced if pull_request.stack.commits.blank?

      pull_request.refresh!
      MergePullRequestsJob.perform_later(pull_request.stack)
    end
  end
end
