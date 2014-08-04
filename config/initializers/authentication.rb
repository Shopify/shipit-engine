Rails.application.config.middleware.use OmniAuth::Builder do
  auth_config = Shipit.authentication

  if Shipit.authentication.present?
    parameters = if auth_config.respond_to?(:options)
      [auth_config.options]
    elsif auth_config.respond_to?(:parameters)
      Array.wrap(auth_config.parameters)
    else
      []
    end
    provider(auth_config.provider, *parameters)
  end

  if Shipit.github
    provider :github, Shipit.github_key, Shipit.github_secret, scope: 'email'
  end
end
