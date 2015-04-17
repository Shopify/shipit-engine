class SetupGithubHookJob < BackgroundJob
  @queue = :default

  def perform(params)
    hook = GithubHook.find(params[:hook_id])
    hook.setup!
  end
end
