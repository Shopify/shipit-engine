class ApplicationController < ActionController::Base
  before_action :authenticate, :force_github_authentication, :set_variant

  def authenticate
    auth_settings = Shipit.authentication
    return if session[:authenticated] || auth_settings.blank?
    redirect_to authentication_path(provider: auth_settings.provider, origin: request.fullpath)
  end

  # Respond to HTML by default
  respond_to :html

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  protected

  def force_github_authentication
    return unless Shipit.github
    if !Shipit.github.try(:optional) && !current_user.logged_in?
      redirect_to authentication_path(:github, origin: request.original_url)
      return false
    end
  end

  def current_user
    @current_user ||= find_current_user || AnonymousUser.new
  end
  helper_method :current_user

  def find_current_user
    return unless session[:user_id].present?
    User.find(session[:user_id])
  rescue ActiveRecord::RecordNotFound
  end

  def set_variant
    if request.negotiate_mime('text/partial+html')
      request.format = :html
      request.variant = :partial
    end
  end
end
