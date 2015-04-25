require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Shipit
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Autoload lib/
    config.autoload_paths += Dir[*%W(
      #{config.root}/lib
      #{config.root}/lib/**/
      #{config.root}/app/serializers/**/
    )]

    # Compile the correct assets
    config.assets.precompile += %w(task.js)
    config.assets.precompile << proc do |path|
      path =~ /\Aplugins\/[\-\w]+\.(js|css)\Z/
    end

    config.active_record.raise_in_transactional_callbacks = true

    Rails.application.routes.default_url_options[:host] = Rails.application.secrets.host

    config.middleware.use Rack::Cors do
      allow do
        origins '*'
        resource '/api/*', headers: :any, methods: %i(head get options put patch post delete)
      end
    end

    ActiveModel::Serializer._root = false
    ActiveModel::ArraySerializer._root = false
  end
end
