class UserRequiredMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    env['rack.session'][:init] = true
    if env['rack.session'][:user] || Setting.authentication.blank?
      @app.call(env)
    else
      [403, {"Content-Type" => "text/html"}, ["Log into Shipit first"]]
    end
  end
end
