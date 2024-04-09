# frozen_string_literal: true

module Shipit
  class SameSiteCookieMiddleware
    COOKIE_SEPARATOR = "\n"

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if headers && headers['Set-Cookie'] &&
          Rack::Request.new(env).ssl?

        set_cookies = headers['Set-Cookie'].split(COOKIE_SEPARATOR).compact
        set_cookies.map! do |cookie|
          cookie << '; Secure' if cookie !~ /;\s*secure/i
          cookie << '; SameSite=None' unless cookie.match?(/;\s*samesite=/i)
          cookie
        end

        headers['Set-Cookie'] = set_cookies.join(COOKIE_SEPARATOR)
      end

      [status, headers, body]
    end
  end
end
