class RefreshGithubUserJob < BackgroundJob
  queue_as :default

  def perform(params)
    user = User.find(params[:user_id])
    user.refresh_from_github!
  end
end
