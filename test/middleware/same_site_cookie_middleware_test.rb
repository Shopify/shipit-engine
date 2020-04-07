require 'test_helper'

module Shipit
  class SameSiteCookieMiddlewareTest < ActiveSupport::TestCase
    def app
      Rack::Lint.new(lambda { |_env|
        response = Rack::Response.new("", 200, "Content-Type" => "text/yaml")

        response.set_cookie("session_test", value: "session_test", domain: ".test.com", path: "/")
        response.finish
      })
    end

    def env_for_url(url)
      env = Rack::MockRequest.env_for(url)
      env
    end

    def middleware
      Shipit::SameSiteCookieMiddleware.new(app)
    end

    test 'SameSite cookie attributes should be added on SSL' do
      env = env_for_url("https://test.com/")

      _status, headers, _body = middleware.call(env)

      assert_includes headers['Set-Cookie'], 'SameSite'
    end

    test 'SameSite cookie attributes should not be added on non SSL requests' do
      env = env_for_url("http://test.com/")

      _status, headers, _body = middleware.call(env)

      assert_not_includes headers['Set-Cookie'], 'SameSite'
    end
  end
end
