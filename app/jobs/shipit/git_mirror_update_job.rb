module Shipit
  class GitMirrorUpdateJob < BackgroundJob
    queue_as :default

    def perform(stack)
      return if stack.inaccessible?

      commands = StackCommands.new(stack)
      stack.acquire_git_cache_lock do
        commands.fetch.run
      end
    end
  end
end
