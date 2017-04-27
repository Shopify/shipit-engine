require 'bootstrap'

module Shipit
  class Engine < ::Rails::Engine
    isolate_namespace Shipit

    Encoding.default_internal = Encoding.default_external = Encoding::UTF_8

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
        shipit_bs.js
        shipit_bs.css
      )
      app.config.assets.precompile << proc do |path|
        path =~ %r{\Aplugins/[\-\w]+\.(js|css)\Z}
      end
      app.config.assets.precompile << proc do |path|
        path.start_with?('emoji/') && path.end_with?('.png')
      end

      ActionDispatch::ExceptionWrapper.rescue_responses[Shipit::TaskDefinition::NotFound.name] = :not_found

      ActiveModel::Serializer._root = false
      ActiveModel::ArraySerializer._root = false
      ActiveModel::Serializer.include(Engine.routes.url_helpers)

      if Shipit.github_oauth_credentials
        OmniAuth::Strategies::GitHub.configure path_prefix: '/github/auth'
        app.middleware.use OmniAuth::Builder do
          provider(
            :github,
            Shipit.github_oauth_id,
            Shipit.github_oauth_secret,
            scope: 'email,repo_deployment',
            client_options: Shipit.github_oauth_options,
          )
        end
      end
    end
  end
end
