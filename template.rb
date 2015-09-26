# Template for rails new app
# Run this like `rails new shipit -m template.rb`
if Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new("4.2.0")
  raise Thor::Error, "You need at least Rails 4.2.0 to install shipit"
end

route %(mount Shipit::Engine, at: '/')

gem 'sidekiq'
gem 'thin'
gem 'shipit-engine', github: 'Shopify/shipit-engine'
gem 'dotenv-rails'

gem_group :development do
  gem 'therubyracer'
end

say("These configs are for development, you will have to generate them again for production.",
    Thor::Shell::Color::GREEN, true)

say("Shipit requires a GitHub application to authenticate users. "\
  "If you haven't created an application on GitHub yet, you can do so at https://github.com/settings/applications/new",
  Thor::Shell::Color::GREEN, true)
github_id = ask("What is the application client ID?")
github_secret = ask("What is the application client secret?")

say("Shipit needs API access to GitHub.")
say("Create an API key at https://github.com/settings/tokens/new that has these permissions: "\
    "admin:repo_hook, admin:org_hook, repo", Thor::Shell::Color::GREEN, true)
github_token = ask("What is the github key?")

create_file '.env', <<-CODE
GITHUB_OAUTH_ID=#{github_id}
GITHUB_OAUTH_SECRET=#{github_secret}
GITHUB_API_TOKEN=#{github_token}
CODE

create_file 'Procfile', <<-CODE
web: bundle exec rails s
worker: bundle exec sidekiq -C config/sidekiq.yml
CODE

create_file 'config/sidekiq.yml', <<-CODE
:concurrency: 1
:queues:
  - default
  - deploys
  - hooks
CODE

create_file 'config/secrets.yml', <<-CODE, force: true
development:
  secret_key_base: #{SecureRandom.hex(64)}
  host: 'http://localhost:3000'
  github_oauth: # Head to https://github.com/settings/applications/new to generate oauth credentials
    id: <%= ENV['GITHUB_OAUTH_ID'] %>
    secret: <%= ENV['GITHUB_OAUTH_SECRET'] %>
    # team: MyOrg/developers # Enable this setting to restrict access to only the member of a team
  github_api:
    access_token: <%= ENV['GITHUB_API_TOKEN'] %>
  redis_url: redis://localhost

test:
  secret_key_base: #{SecureRandom.hex(64)}
  host: 'http://localhost:4000'
  github_oauth:
    id: 1d
    secret: s3cr3t
  github_api:
    access_token: t0k3n
  redis_url: redis://localhost

production:
  secret_key_base: <%= ENV['SECRET_KEY_BASE'] %>
  host: <%= ENV['SHIPIT_HOST'] %>
  github_oauth:
    id: <%= ENV['GITHUB_OAUTH_ID'] %>
    secret: <%= ENV['GITHUB_OAUTH_SECRET'] %>
    # team: MyOrg/developers # Enable this setting to restrict access to only the member of a team
  github_api:
    access_token: <%= ENV['GITHUB_API_TOKEN'] %>
  redis_url: <%= ENV['REDIS_URL'] %>
  env:
    # SSH_AUTH_SOCK: /foo/bar # You can set environment variable that will be present during deploys.
CODE

initializer 'sidekiq.rb', <<-CODE
Rails.application.config.active_job.queue_adapter = :sidekiq

Sidekiq.configure_server do |config|
  config.redis = { url: Shipit.redis_url.to_s }
end

Sidekiq.configure_client do |config|
  config.redis = { url: Shipit.redis_url.to_s }
end
CODE

if yes?("Are you hosting Shipit on Heroku? (y/n)")
  inject_into_file "Procfile", " -p $PORT", after: "web: bundle exec rails s"
  inject_into_file "Gemfile", "ruby '2.2.3'", after: "source 'https://rubygems.org'\n"

  gsub_file 'Gemfile', "# Use sqlite3 as the database for Active Record", ''
  gsub_file 'Gemfile', "gem 'sqlite3'", ''
  gem_group :production do
    gem 'pg'
    gem 'rails_12factor'
  end
  gem_group :development, :test do
    gem 'sqlite3'
  end

  remove_file 'config/database.yml'
  create_file 'config/database.yml', <<-EOF
default: &default
  adapter: sqlite3
  pool: 5
  timeout: 5000

development:
  <<: *default
  database: db/development.sqlite3

# Warning: The database defined as "test" will be erased and
# re-generated from your development database when you run "rake".
# Do not set this db to the same as development or production.
test:
  <<: *default
  database: db/test.sqlite3

production:
  url:  <%= ENV['DATABASE_URL'] %>
  pool: <%= ENV['DB_POOL'] || 5 %>

EOF
end

after_bundle do
  rake 'railties:install:migrations db:create db:migrate'

  git :init
  run "echo '.env' >> .gitignore"
  git add: '.'
  git commit: "-a -m 'Initial commit'"
end
