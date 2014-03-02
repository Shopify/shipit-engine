Rails.application.config.middleware.use OmniAuth::Builder do
  auth_config = Settings.authentication
  options = { callback_path: '/authentication/finalize' }

  options = options.merge(auth_config.options) if auth_config.respond_to?(:options)
  provider auth_config.provider, options
end unless Settings.authentication.blank?
