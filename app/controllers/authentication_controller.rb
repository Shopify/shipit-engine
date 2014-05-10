class AuthenticationController < ApplicationController
  skip_before_filter :authenticate, :force_github_authentication, :verify_authenticity_token, :only => :callback

  def callback
    return_url = params[:origin] || root_path
    auth = request.env['omniauth.auth']

    return render 'failed', layout: false if auth.blank?

    sign_in_github(auth)

    if Settings.authentication.blank?
      return redirect_to return_url
    end

    session[:authenticated] = true if auth['provider'] == Settings.authentication.provider

    redirect_to return_url
  end

  def logout
    reset_session
    redirect_to root_path
  end

  private

  def sign_in_github(auth)
    return unless auth[:provider] == 'github'

    user = Shipit.github_api.user(auth[:info][:nickname])
    session[:user_id] = User.find_or_create_from_github(user).id
  end
end
