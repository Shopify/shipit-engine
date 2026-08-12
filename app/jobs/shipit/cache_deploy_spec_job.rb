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

      commit = stack.commits.reachable.last
      commands = Commands.for(stack)
      spec = commands.cacheable_deploy_spec(commit:)
      stack.update!(cached_deploy_spec: spec)

      # A duplicate enqueued while this job held the dedupe lock was dropped;
      # if the head moved under us, that dropped job's work is still
      # outstanding, so hand it off rather than leaving the spec stale.
      CacheDeploySpecJob.perform_later(stack) if stack.commits.reachable.last&.id != commit&.id
    end
  end
end
