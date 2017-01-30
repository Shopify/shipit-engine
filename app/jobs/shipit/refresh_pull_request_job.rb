module Shipit
  class RefreshPullRequestJob < BackgroundJob
    def perform(pull_request)
      pull_request.refresh!
    end
  end
end
