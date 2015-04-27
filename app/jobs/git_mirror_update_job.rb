class GitMirrorUpdateJob < BackgroundJob
  queue_as :default

  def perform(stack)
    commands = StackCommands.new(stack)
    commands.fetch.run
  end
end
