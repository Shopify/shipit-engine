module Shipit
  class RefreshPullRequestJob < BackgroundJob
    queue_as :default

    def perform(pull_request)
      pull_request.refresh!
      MergePullRequestsJob.perform_later(pull_request.stack) if pull_request.merge_request?
    end
  end
end
