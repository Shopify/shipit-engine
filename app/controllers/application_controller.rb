class ApplicationController < ActionController::Base
  before_filter :authenticate
  before_action :set_variant

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
    @menu ||= Menu.new(non_favourite_stacks)
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

  def favourites_menu
    @favourites_menu ||= Menu.new(favourite_stacks)
  end
  helper_method :favourites_menu

  def favourite_stacks
    return @favourite_stacks if @favourite_stacks

    if current_user
      @favourite_stacks = FavouriteStack.where(user_id: current_user.id).map(&:stack)
    else
      @favourite_stacks = []
    end
  end
  helper_method :favourite_stacks

  def non_favourite_stacks
    favourites_ids = favourite_stacks.map(&:id)

    favourites_ids.any? ? Stack.where('id NOT IN (?)', favourites_ids) : Stack.all
  end
end
