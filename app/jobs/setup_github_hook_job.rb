class SetupGithubHookJob < BackgroundJob
  queue_as :default

  def perform(hook)
    hook.setup!
  end
end
