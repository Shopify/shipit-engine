class ApplicationController < ActionController::Base
  before_filter :authenticate
  before_action :set_variant

  def authenticate
    auth_settings = Settings.authentication
    return if session[:authenticated] || auth_settings.blank?
    session[:return_to] = request.fullpath
    redirect_to authentication_path(provider: auth_settings.provider, origin: request.fullpath)
  rescue Settingslogic::MissingSetting
  end

  # Respond to HTML by default
  respond_to :html

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  protected

  def current_user
    @current_user ||= begin
      User.find(session[:user_id])
    rescue ActiveRecord::RecordNotFound
      AnonymousUser.new
    end
  end
  helper_method :current_user

  def menu
    @menu ||= Menu.new
  end
  helper_method :menu

  def set_variant
    if request.negotiate_mime('text/partial+html')
      request.format = :html
      request.variant = :partial
    end
  end
end
