module Shipit
  class RefreshPullRequestJob < BackgroundJob
    def perform(pull_request)
      pull_request.refresh!
      MergePullRequestsJob.perform_later(pull_request.stack)
    end
  end
end
