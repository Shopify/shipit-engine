class AuthenticationController < ApplicationController
  skip_before_filter :authenticate, :force_github_authentication, :verify_authenticity_token, :only => :callback

  def callback
    return_url = params[:origin] || root_path
    auth = request.env['omniauth.auth']

    return render 'failed', layout: false if auth.blank?

    user_id = sign_in_github(auth) || session[:user_id]
    session[:user_id] = user_id

    authenticate_user(auth, user_id)
    redirect_to return_url
  end

  def logout
    reset_session
    redirect_to root_path
  end

  private

  def authenticate_user(auth, user_id)
    return if Shipit.authentication.blank?

    reset_session
    session[:authenticated] = valid_provider_auth?(auth)
    session[:user_id] = user_id
  end

  def valid_provider_auth?(auth)
    return false unless auth['provider'] == Shipit.authentication['provider']

    email_domain = Shipit.authentication['email_domain'] || "shopify.com"

    auth['info']['email'].match(/@#{Regexp.escape(email_domain)}\z/).present?
  end

  def sign_in_github(auth)
    return unless auth[:provider] == 'github'

    user = Shipit.github_api.user(auth[:info][:nickname])
    User.find_or_create_from_github(user).id
  end
end
