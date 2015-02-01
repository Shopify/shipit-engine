class CacheDeploySpecJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform
    stack.update!(cached_deploy_spec: commands.build_cacheable_deploy_spec)
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end

  def commands
    @commands ||= StackCommands.new(stack)
  end
end
