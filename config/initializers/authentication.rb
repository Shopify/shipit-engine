Rails.application.config.middleware.use OmniAuth::Builder do
  auth_config = Settings.authentication

  if Settings.authentication.present?
    parameters = if auth_config.respond_to?(:options)
      [auth_config.options]
    elsif auth_config.respond_to?(:parameters)
      Array.wrap(auth_config.parameters)
    else
      []
    end
    provider(auth_config.provider, *parameters)
  end

  provider :github, Settings.github.key, Settings.github.secret, scope: "email" if Settings.github
end
