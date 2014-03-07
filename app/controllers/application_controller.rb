class ApplicationController < ActionController::Base
  before_filter :authenticate

  def authenticate
    auth_settings = Settings['authentication']
    return if session[:user] || auth_settings.blank?
    session[:return_to] = request.fullpath
    redirect_to authentication_path(provider: auth_settings.provider)
  end

  # Respond to HTML by default
  respond_to :html

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
end
