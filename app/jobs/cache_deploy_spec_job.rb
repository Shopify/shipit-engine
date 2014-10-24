class CacheDeploySpecJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform(params)
    stack = Stack.find(params[:stack_id])
    commands = StackCommands.new(stack)
    @stack.update!(cached_deploy_spec: commands.build_cacheable_deploy_spec)
  end
end
