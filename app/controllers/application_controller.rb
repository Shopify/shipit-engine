class ApplicationController < ActionController::Base
  before_filter :authenticate
  before_action :set_variant
  before_filter :set_favourite_stacks

  def authenticate
    auth_settings = Settings.authentication
    return if session[:user] || auth_settings.blank?
    session[:return_to] = request.fullpath
    redirect_to authentication_path(provider: auth_settings.provider)
  rescue Settingslogic::MissingSetting
  end

  # Respond to HTML by default
  respond_to :html

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  protected

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

  def current_user
    return nil unless session[:user]

    email = session[:user][:email]

    @current_user ||= User.where(email: email).first
  end

  def set_favourite_stacks
    if current_user
      @favourite_stacks = FavouriteStack.where(user_id: current_user.id).order(position: :desc, created_at: :desc).includes(:stack).map(&:stack)
    else
      @favourite_stacks = []
    end
  end
end
