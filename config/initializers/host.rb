Rails.application.routes.default_url_options[:host] = Settings[:host] or raise "Missing required `host` configuration in settings.yml"
