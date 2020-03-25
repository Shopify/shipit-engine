# typed: false
require 'test_helper'

module Shipit
  class GithubAuthenticationControllerTest < ActionController::TestCase
    test ":callback can sign in to github" do
      auth = OmniAuth::AuthHash.new(
        credentials: OmniAuth::AuthHash.new(
          token: 's3cr3t',
        ),
        extra: OmniAuth::AuthHash.new(
          raw_info: OmniAuth::AuthHash.new(
            id: 44,
            name: 'Shipit User',
            email: 'shipit-user@example.com',
            login: 'shipit-user',
            avatar_url: 'https://example.com',
            api_url: 'https://github.com/api/v3/users/shipit-user',
          ),
        ),
      )
      @request.env['omniauth.auth'] = auth

      assert_difference -> { User.count } do
        get :callback
      end

      user = User.find_by(login: 'shipit-user')
      assert_equal 's3cr3t', user.github_access_token
      assert_equal 44, user.github_id
    end
  end
end
