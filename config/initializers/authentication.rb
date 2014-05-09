Rails.application.config.middleware.use OmniAuth::Builder do
  auth_config = Settings.authentication

  options = auth_config.options if auth_config.respond_to?(:options)
  provider auth_config.provider, options

  provider :github, Settings.github.key, Settings.github.secret, scope: "email" if Settings.github
end unless Settings.authentication.blank?
