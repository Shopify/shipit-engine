class AuthenticationController < ApplicationController
  skip_before_filter :authenticate, :verify_authenticity_token, :only => :callback

  def callback
    return_url = session[:return_to] || root_path

    unless Settings.authentication.present?
      return redirect_to return_url
    end

    auth = request.env['omniauth.auth']
    if auth.blank?
      return render 'failed'
    end

    reset_session

    session[:user] = {
      email: auth['info']['email'],
      name: auth['info']['name'],
      first_name: auth['info']['first_name'],
      last_name: auth['info']['last_name']
    }
    redirect_to return_url
  end

  def logout
    reset_session
    redirect_to root_path
  end
end
