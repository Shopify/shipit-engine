class SetupGithubHookJob < BackgroundJob
  include BackgroundJob::Unique

  queue_as :default

  def perform(hook)
    hook.setup!
  end
end
