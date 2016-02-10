module Shipit
  class FetchDeployedRevisionJob < BackgroundJob
    queue_as :default

    def perform(stack)
      return if stack.active_task?

      commands = StackCommands.new(stack)

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
  end
end
