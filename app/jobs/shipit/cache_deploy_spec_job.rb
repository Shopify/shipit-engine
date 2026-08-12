# frozen_string_literal: true

module Shipit
  class CacheDeploySpecJob < BackgroundJob
    include BackgroundJob::Unique
    on_duplicate :drop

    queue_as :deploys

    # Caps job execution AND sets the dedupe lock expiration to match.
    # Without it the lock falls back to Unique::DEFAULT_TIMEOUT (10s), which is
    # far shorter than the job's runtime, letting duplicate jobs for the same
    # stack run concurrently once the lock expires mid-run.
    self.timeout = 15.minutes.to_i

    def perform(stack)
      return if stack.inaccessible?

      commands = Commands.for(stack)
      commands.with_temporary_working_directory(commit: stack.commits.reachable.last, recursive: false) do |path|
        stack.update!(cached_deploy_spec: DeploySpec::FileSystem.new(path, stack))
      end
    end
  end
end
