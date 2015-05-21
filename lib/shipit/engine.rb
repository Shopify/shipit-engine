module Shipit
  class Engine < ::Rails::Engine
    paths['app/models'] << 'app/serializers' << 'app/serializers/concerns'

    initializer 'shipit.config' do |app|
      Rails.application.routes.default_url_options[:host] = Shipit.host
      Shipit::Engine.routes.default_url_options[:host] = Shipit.host

      app.config.assets.precompile += %w(
        task.js
        shipit.js
        shipit.css
      )
      app.config.assets.precompile << proc do |path|
        path =~ /\Aplugins\/[\-\w]+\.(js|css)\Z/
      end

      ActiveModel::Serializer._root = false
      ActiveModel::ArraySerializer._root = false
      ActiveModel::Serializer.include(Engine.routes.url_helpers)

      if Shipit.github_oauth_credentials
        OmniAuth::Strategies::GitHub.configure path_prefix: '/github/auth'
        app.middleware.use OmniAuth::Builder do
          provider(:github, Shipit.github_oauth_id, Shipit.github_oauth_secret, scope: 'email')
        end
      end
    end
  end
end
