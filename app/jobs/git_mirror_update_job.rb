class GitMirrorUpdateJob < BackgroundJob
  queue_as :default

  extend BackgroundJob::StackExclusive

  def perform(params)
    stack = Stack.find(params[:stack_id])
    commands = StackCommands.new(stack)
    commands.fetch.run
  end
end
