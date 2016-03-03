module Shipit
  class GithubAuthenticationController < ActionController::Base
    include Shipit::Engine.routes.url_helpers

    def callback
      return_url = request.env['omniauth.origin'] || root_path
      auth = request.env['omniauth.auth']

      return render 'failed', layout: false if auth.blank?

      session[:user_id] = sign_in_github(auth)

      redirect_to return_url
    end

    def logout
      reset_session
      redirect_to root_path
    end

    private

    def sign_in_github(auth)
      user = User.find_or_create_from_github(auth.extra.raw_info)
      user.update(github_access_token: auth.credentials.token)
      user.id
    end
  end
end
