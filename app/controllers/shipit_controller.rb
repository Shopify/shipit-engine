class ShipitController < ApplicationController
  layout 'shipit'

  helper Shipit::Engine.routes.url_helpers
  include Shipit::Engine.routes.url_helpers

  before_action :ensure_required_settings,
                :force_github_authentication,
                :set_variant

  # Respond to HTML by default
  respond_to :html

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  private

  def ensure_required_settings
    return if Shipit.all_settings_present?

    render 'missing_settings'
  end

  def force_github_authentication
    if current_user.logged_in?
      team = Shipit.github_team
      if team && !current_user.in?(team.members)
        render text: "You must be a member of #{team.handle} to access this application.", status: :forbidden
      end
    else
      redirect_to Shipit::Engine.routes.url_helpers.github_authentication_path(origin: request.original_url)
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
    return unless request.negotiate_mime('text/partial+html')

    request.format = :html
    request.variant = :partial
  end
end
