module Shipit
  class AppendDelayedReleaseStatusJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    def lock_key(deploy, *)
      super(deploy)
    end

    def perform(deploy, cursor:, status:, description:)
      return unless cursor == deploy.until_commit.release_statuses.last

      deploy.append_release_status(status, description)
    end
  end
end
