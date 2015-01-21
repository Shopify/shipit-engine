Rails.application.config.middleware.use OmniAuth::Builder do
  provider(*Shipit.authentication_settings) if Shipit.authentication
  provider(:github, Shipit.github_key, Shipit.github_secret, scope: 'email') if Shipit.github
end
