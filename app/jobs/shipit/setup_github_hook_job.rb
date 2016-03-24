module Shipit
  class SetupGithubHookJob < BackgroundJob
    include BackgroundJob::Exclusive

    queue_as :default

    def perform(hook)
      hook.setup!
    end
  end
end
