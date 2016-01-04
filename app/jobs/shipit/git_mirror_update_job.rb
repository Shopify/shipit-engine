module Shipit
  class GitMirrorUpdateJob < BackgroundJob
    queue_as :default

    def perform(stack)
      commands = StackCommands.new(stack)
      stack.acquire_git_cache_lock do
        commands.fetch.run
      end
    end
  end
end
