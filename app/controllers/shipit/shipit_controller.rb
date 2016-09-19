module Shipit
  class ShipitController < ApplicationController
    layout 'shipit'

    helper GithubUrlHelper
    helper StacksHelper
    helper TasksHelper
    helper DeploysHelper
    helper ChunksHelper

    helper Shipit::Engine.routes.url_helpers
    include Shipit::Engine.routes.url_helpers
    include ActionView::Helpers::DateHelper

    before_action(
      :toogle_bootstrap_feature,
      :ensure_required_settings,
      :force_github_authentication,
      :set_variant,
      :check_github_status
    )

    # Respond to HTML by default
    respond_to :html

    # Prevent CSRF attacks by raising an exception.
    # For APIs, you may want to use :null_session instead.
    protect_from_forgery with: :exception

    private

    def toogle_bootstrap_feature
      prepend_view_path(Shipit.bootstrap_view_path) if Shipit.feature_bootstrap?
    end

    def ensure_required_settings
      return if Shipit.all_settings_present?

      render 'shipit/missing_settings'
    end

    def force_github_authentication
      if current_user.logged_in?
        teams = Shipit.github_teams
        unless teams.empty? || current_user.teams.where(id: teams).exists?
          team_list = teams.map(&:handle).to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')
          render text: "You must be a member of #{team_list} to access this application.", status: :forbidden
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

    def check_github_status
      github_status = Rails.cache.read('github::status')
      return if github_status.nil? || github_status[:status] == 'good'

      flash[:warning] = "It seems that GitHub is having issues:
        status: #{github_status[:status]} '#{github_status[:body]}'
        updated: #{time_ago_in_words(github_status[:last_updated])} ago"
    end
  end
end
