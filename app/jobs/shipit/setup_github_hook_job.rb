module Shipit
  class SetupGithubHookJob < BackgroundJob
    queue_as :default

    def perform(hook)
      # TODO: app-migration, delete this job
    end
  end
end
