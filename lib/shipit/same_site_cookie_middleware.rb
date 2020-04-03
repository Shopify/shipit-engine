module Shipit
  class SameSiteCookieMiddleware
    COOKIE_SEPARATOR = "\n".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      user_agent = env['HTTP_USER_AGENT']

      if headers && headers['Set-Cookie'] &&
         BrowserSniffer.new(user_agent).same_site_none_compatible? &&
         env['SHIPIT_ENABLE_SAMESITE_NONE'].present? &&
         Rack::Request.new(env).ssl?

        set_cookies = headers['Set-Cookie']
                      .split(COOKIE_SEPARATOR)
                      .compact
                      .map do |cookie|
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
