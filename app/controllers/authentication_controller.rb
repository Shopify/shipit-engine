class AuthenticationController < ApplicationController
  skip_before_filter :authenticate, :verify_authenticity_token, :only => :finalize

  def finalize
    return_url = session[:return_to] || root_path

    unless Settings.authentication.present?
      return redirect_to return_url
    end

    auth = request.env['omniauth.auth']
    if auth.blank?
      return render :inline => '<h3>Snowman says No</h3><h1 style="text-align:center; font-size:4000%;">&#9731;</h1>'
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
