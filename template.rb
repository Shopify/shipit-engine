# Template for rails new app
# Run this like `rails new shipit -m template.rb`
if Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new("4.2.0")
  raise Thor::Error, "You need at least Rails 4.2.0 to install shipit"
end

route %(mount Shipit::Engine, at: '/')

gem 'sidekiq'
gem 'thin'
gem 'shipit-engine'

say("This configs are for development, you will have to generate them again for production.",
    Thor::Shell::Color::GREEN, true)
say("Create a GitHub application (https://github.com/settings/applications/new) to generate oauth credentials.",
    Thor::Shell::Color::GREEN, true)
github_id = ask("What is the Client ID?")
github_secret = ask("What is the Client Secret?")

say("Create an API key (https://github.com/settings/tokens/new) that has these permissions: "\
    "admin:repo_hook, admin:org_hook, repo", Thor::Shell::Color::GREEN, true)
github_token = ask("What is the github key?")

create_file 'config/secrets.yml', <<-CODE, force: true
development:
  secret_key_base: #{SecureRandom.hex(64)}
  host: 'http://localhost:3000'
  github_oauth: # Head to https://github.com/settings/applications/new to generate oauth credentials
    id: #{github_id}
    secret: #{github_secret}
    # team: MyOrg/developers # Enable this setting to restrict access to only the member of a team
  github_api:
    access_token: #{github_token}

test:
  secret_key_base: #{SecureRandom.hex(64)}
  host: 'http://localhost:4000'
  github_oauth:
    id: 1d
    secret: s3cr3t
  github_api:
    access_token: t0k3n

production:
  secret_key_base: <%= ENV['SECRET_KEY_BASE'] %>
  host: <%= ENV['SHIPIT_HOST'] %>
  github_oauth:
    id: <%= ENV['GITHUB_OAUTH_ID'] %>
    secret: <%= ENV['GITHUB_OAUTH_SECRET'] %>
    # team: MyOrg/developers # Enable this setting to restrict access to only the member of a team
  github_api:
    access_token: <%= ENV['GITHUB_API_TOKEN'] %>
  env:
    # SSH_AUTH_SOCK: /foo/bar # You can set environment variable that will be present during deploys.
CODE

after_bundle do
  rake 'railties:install:migrations db:create db:migrate'
end
