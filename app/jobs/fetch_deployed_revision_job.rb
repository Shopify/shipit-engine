class FetchDeployedRevisionJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform(params)
    stack = Stack.find(params[:stack_id])
    return if stack.deploying?
    commands = StackCommands.new(stack)
    if sha = commands.fetch_deployed_revision
      stack.update_deployed_revision(sha)
    end
  rescue ActiveRecord::RecordNotFound
  end

end
