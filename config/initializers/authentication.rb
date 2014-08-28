Rails.application.config.middleware.use OmniAuth::Builder do
  if auth_config = Shipit.authentication
    provider(*Shipit.authentication_settings)
  end

  if github_config = Shipit.github
    provider(:github, Shipit.github_key, Shipit.github_secret, scope: 'email')
  end
end
