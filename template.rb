gem 'sidekiq'
gem 'thin'
gem 'shipit-engine', path: __dir__

route "mount Shipit::Engine, at: '/'"

file 'config/secrets.yml', <<-CODE
  # Be sure to restart your server when you modify this file.

  # Your secret key is used for verifying the integrity of signed cookies.
  # If you change this key, all old signed cookies will become invalid!

  # Make sure the secret is at least 30 characters and all random,
  # no regular words or you'll be exposed to dictionary attacks.
  # You can use `rake secret` to generate a secure secret key.

  # Make sure the secrets in this file are kept private
  # if you're sharing your code publicly.

  development:
    secret_key_base: #{SecureRandom.hex(64)}
    host: 'http://localhost:3000'
    github_oauth: # Head to https://github.com/settings/applications/new to generate oauth credentials
      id:
      secret:
      # team: MyOrg/developers # Enable this setting to restrict access to only the member of a team
    github_api:
      access_token: # Head to https://github.com/settings/tokens to generate a token

  test:
    secret_key_base: #{SecureRandom.hex(64)}
    host: 'http://shipit.example.com'
    github_oauth: # Head to https://github.com/settings/applications/new to generate oauth credentials
      id: 1d
      secret: s3cr3t
      # team: MyOrg/developers # Enable this setting to restrict access to only the member of a team
    github_api:
      access_token: t0k3n # Head to https://github.com/settings/tokens to generate a token

  # Do not keep production secrets in the repository,
  # instead read values from the environment.
  production:
    secret_key_base: <%= ENV['SECRET_KEY_BASE'] %>
    host: <%= ENV['SHIPIT_HOST'] %>
    github_oauth: # Head to https://github.com/settings/applications/new to generate oauth credentials
      id: <%= ENV['GITHUB_OAUTH_ID'] %>
      secret: <%= ENV['GITHUB_OAUTH_SECRET'] %>
      # team: MyOrg/developers # Enable this setting to restrict access to only the member of a team
    github_api:
      access_token: <%= ENV['GITHUB_API_TOKEN'] %> # Head to https://github.com/settings/tokens to generate a token
    env:
      # SSH_AUTH_SOCK: /foo/bar # You can set environment variable that will be present during deploys.
CODE

after_bundle do
  rake 'railties:install:migrations db:create db:migrate'
end
