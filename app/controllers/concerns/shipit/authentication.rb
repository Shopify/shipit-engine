module Shipit
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :force_github_authentication
      helper_method :current_user
    end

    module ClassMethods
      def skip_authentication(*args)
        skip_before_action(:force_github_authentication, *args)
      end
    end

    private

    def force_github_authentication
      if Shipit.authentication_disabled? || current_user.logged_in?
        unless current_user.authorized?
          team_handles = Shipit.github_teams.map(&:handle)
          team_list = team_handles.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')
          render plain: "You must be a member of #{team_list} to access this application.", status: :forbidden
        end
      else
        redirect_to Shipit::Engine.routes.url_helpers.github_authentication_path(origin: request.original_url)
      end
    end

    def current_user
      @current_user ||= find_current_user || AnonymousUser.new
    end

    def find_current_user
      session[:user_id].present? && User.find_by(id: session[:user_id])
    end
  end
end
