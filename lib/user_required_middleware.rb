class UserRequiredMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    env['rack.session'][:init] = true
    if env['rack.session'][:authenticated] || Shipster.authentication.blank?
      @app.call(env)
    else
      [403, {"Content-Type" => "text/html"}, ["Log into Shipster first"]]
    end
  end
end
