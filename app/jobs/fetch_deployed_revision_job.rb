class FetchDeployedRevisionJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform
    return if stack.deploying?

    begin
      sha = commands.fetch_deployed_revision
    rescue DeploySpec::Error
    end

    return unless sha.present?

    begin
      stack.update_deployed_revision(sha)
    rescue ActiveRecord::RecordNotFound
    end
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end

  def commands
    @commands ||= StackCommands.new(stack)
  end
end
