module Shipit
  class CacheDeploySpecJob < BackgroundJob
    include BackgroundJob::Exclusive

    def perform(stack)
      commands = Commands.for(stack)
      commands.with_temporary_working_directory(commit: stack.commits.last) do |path|
        stack.update!(cached_deploy_spec: DeploySpec::FileSystem.new(path, stack.environment))
      end
    end
  end
end
