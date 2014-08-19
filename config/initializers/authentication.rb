Rails.application.config.middleware.use OmniAuth::Builder do
  if auth_config = Shipit.authentication
    parameters = Array(auth_config['parameters'] || auth_config['options'])
    provider(auth_config['provider'], *parameters)
  end

  if github_config = Shipit.github
    provider :github, github_config['key'], github_config['secret'], scope: 'email'
  end
end
