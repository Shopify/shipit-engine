module Shipster
  class Engine < ::Rails::Engine
    paths['app/models'] << 'app/serializers' << 'app/serializers/concerns'

    initializer 'shipster.config' do |app|
      Rails.application.routes.default_url_options[:host] = Shipster.host
      Shipster::Engine.routes.default_url_options[:host] = Shipster.host

      app.config.assets.precompile += %w(
        task.js
        shipster.js
        shipster.css
      )
      app.config.assets.precompile << proc do |path|
        path =~ /\Aplugins\/[\-\w]+\.(js|css)\Z/
      end

      ActiveModel::Serializer._root = false
      ActiveModel::ArraySerializer._root = false
      ActiveModel::Serializer.include(Engine.routes.url_helpers)

      if Shipster.github
        OmniAuth::Strategies::GitHub.configure path_prefix: '/github/auth'
        app.middleware.use OmniAuth::Builder do
          provider(:github, Shipster.github_key, Shipster.github_secret, scope: 'email')
        end
      end
    end
  end
end
