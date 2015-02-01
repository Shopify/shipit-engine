class GitMirrorUpdateJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform
    Commands.for(stack).fetch.run!
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end
end
