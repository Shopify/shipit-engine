# frozen_string_literal: true
module Shipit
  class Engine < ::Rails::Engine
    isolate_namespace Shipit

    paths['app/models'] << 'app/serializers' << 'app/serializers/concerns'

    initializer 'shipit.config' do |app|
      Rails.application.routes.default_url_options[:host] = Shipit.host
      Shipit::Engine.routes.default_url_options[:host] = Shipit.host
      Pubsubstub.redis_url = Shipit.redis_url.to_s

      app.config.assets.paths << Emoji.images_path
      app.config.assets.precompile += %w(
        favicon.ico
        task.js
        shipit.js
        shipit.css
        merge_status.js
        merge_status.css
      )
      app.config.assets.precompile << proc do |path|
        path =~ %r{\Aplugins/[\-\w]+\.(js|css)\Z}
      end
      app.config.assets.precompile << proc do |path|
        path.end_with?('.svg') || (path.start_with?('emoji/') && path.end_with?('.png'))
      end

      ActionDispatch::ExceptionWrapper.rescue_responses[Shipit::TaskDefinition::NotFound.name] = :not_found

      if Shipit.github.oauth?
        OmniAuth::Strategies::GitHub.configure(path_prefix: '/github/auth')
        app.middleware.use(OmniAuth::Builder) do
          provider(:github, *Shipit.github.oauth_config)
        end
      end

      if Shipit.enable_samesite_middleware?
        app.config.middleware.insert_after(::Rack::Runtime, Shipit::SameSiteCookieMiddleware)
      end
    end
  end
end
