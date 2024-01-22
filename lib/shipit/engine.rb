# frozen_string_literal: true

module Shipit
  class Engine < ::Rails::Engine
    isolate_namespace Shipit

    paths['app/models'] << 'app/serializers' << 'app/serializers/concerns'

    initializer 'shipit.encryption_config', before: 'active_record_encryption.configuration' do |app|
      if app.credentials.active_record_encryption.blank? && Shipit.user_access_tokens_key.present?
        # For ease of upgrade, we derive an Active Record encryption config automatically.
        # But if AR Encryption is already configured, we just use that
        app.credentials[:active_record_encryption] = {
          primary_key: Shipit.user_access_tokens_key,
          key_derivation_salt: Digest::SHA256.digest("salt:".b + Shipit.user_access_tokens_key),
        }
      end
    end

    initializer 'shipit.config' do |app|
      Rails.application.routes.default_url_options[:host] = Shipit.host
      Shipit::Engine.routes.default_url_options[:host] = Shipit.host
      Pubsubstub.redis_url = Shipit.redis_url.to_s

      Rails.application.credentials.deep_symbolize_keys!

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

      ActiveModel::Serializer._root = false
      ActiveModel::ArraySerializer._root = false
      ActiveModel::Serializer.include(Engine.routes.url_helpers)

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

    config.after_initialize do
      ActionDispatch::ExceptionWrapper.rescue_responses[Shipit::TaskDefinition::NotFound.name] = :not_found
      ActionController::Base.include(Shipit::ActiveModelSerializersPatch)
    end
  end
end
