class GitMirrorUpdateJob < BackgroundJob
  queue_as :default

  extend BackgroundJob::StackExclusive

  def perform(stack)
    commands = StackCommands.new(stack)
    commands.fetch.run
  end
end
