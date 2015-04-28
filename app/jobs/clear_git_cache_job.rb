class ClearGitCacheJob < BackgroundJob
  queue_as :default

  def perform(stack)
    stack.clear_git_cache!
  end
end
