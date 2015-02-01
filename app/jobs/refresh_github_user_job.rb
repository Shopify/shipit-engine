class RefreshGithubUserJob < BackgroundJob
  @queue = :default

  def perform
    user.refresh_from_github!
  end

  private

  def user
    @user ||= User.find(params[:user_id])
  end
end
