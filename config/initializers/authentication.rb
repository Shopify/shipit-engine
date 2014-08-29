Rails.application.config.middleware.use OmniAuth::Builder do
  if Shipit.authentication
    provider(*Shipit.authentication_settings)
  end

  if Shipit.github
    provider(:github, Shipit.github_key, Shipit.github_secret, scope: 'email')
  end
end
