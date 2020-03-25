# typed: false
module Shipit
  class ClearGitCacheJob < BackgroundJob
    queue_as :deploys

    def perform(stack)
      stack.clear_git_cache!
    end
  end
end
