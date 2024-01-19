# Template for rails new app
# Run this like `rails new shipit -m template.rb`
if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.7')
  raise Thor::Error, "You need at least Ruby 2.7 to install shipit"
end
if Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new('7.1.1')
  raise Thor::Error, "You need Rails 7.1.1 to install shipit"
end

route %(mount Shipit::Engine, at: '/')

gem 'sidekiq'
if ENV['SHIPIT_GEM_PATH']
  gem 'shipit-engine', path: ENV['SHIPIT_GEM_PATH']
else
  gem 'shipit-engine'
end
gsub_file 'Gemfile', "# Use Redis adapter to run Action Cable in production", ''
gsub_file 'Gemfile', "# gem 'redis'", "gem 'redis'"

create_file 'Procfile', <<-CODE
web: bundle exec rails s -p $PORT
worker: bundle exec sidekiq -C config/sidekiq.yml
CODE

environment 'Pubsubstub.use_persistent_connections = false'
environment 'config.cache_store = :redis_cache_store, { url: Shipit.redis_url.to_s, expires_in: 90.minutes }', env: :production

remove_file 'config/database.yml'
create_file 'config/database.yml', <<-CODE
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
CODE

create_file 'config/sidekiq.yml', <<-CODE
:concurrency: 1
:queues:
  - default
  - deploys
  - hooks
  - low
CODE

%w(config/secrets.yml config/secrets.example.yml).each do |path|
  create_file path, <<~CODE, force: true
    development:
      app_name: My Shipit
      secret_key_base: #{SecureRandom.hex(64)}
      host: 'http://localhost:3000'
      redis_url: redis://localhost
      github:
        domain: # defaults to github.com
        bot_login:
        app_id:
        installation_id:
        webhook_secret:
        private_key:
        oauth:
          id:
          secret:
          # team: MyOrg/developers # Enable this setting to restrict access to only the member of a team

    test:
      app_name: My Shipit
      secret_key_base: #{SecureRandom.hex(64)}
      host: 'http://localhost:4000'
      redis_url: redis://localhost
      github:
        domain: # defaults to github.com
        bot_login:
        app_id:
        installation_id:
        webhook_secret:
        private_key:
        oauth:
          id: <%= ENV['GITHUB_OAUTH_ID'] %>
          secret: <%= ENV['GITHUB_OAUTH_SECRET'] %>
          # teams: MyOrg/developers # Enable this setting to restrict access to only the member of a team

    production:
      app_name: My Shipit
      secret_key_base: <%= ENV['SECRET_KEY_BASE'] %>
      host: <%= ENV['SHIPIT_HOST'] %>
      redis_url: <%= ENV['REDIS_URL'] %>
      github:
        domain: # defaults to github.com
        app_id: <%= ENV['GITHUB_APP_ID'] %>
        installation_id: <%= ENV['GITHUB_INSTALLATION_ID'] %>
        webhook_secret:
        private_key:
        oauth:
          id: <%= ENV['GITHUB_OAUTH_ID'] %>
          secret: <%= ENV['GITHUB_OAUTH_SECRET'] %>
          # teams: MyOrg/developers # Enable this setting to restrict access to only the member of a team
      env:
        # SSH_AUTH_SOCK: /foo/bar # You can set environment variable that will be present during deploys.
  CODE
end

initializer 'sidekiq.rb', <<-CODE
Sidekiq.configure_server do |config|
  config.redis = { url: Shipit.redis_url.to_s }
end

Sidekiq.configure_client do |config|
  config.redis = { url: Shipit.redis_url.to_s }
end
CODE

inject_into_file 'config/application.rb', after: "load_defaults 7.1\n" do
  "\n    config.active_job.queue_adapter = :sidekiq\n"
end

after_bundle do
  run 'bundle exec rake railties:install:migrations db:create db:migrate'

  git :init
  run "echo 'config/secrets.yml' >> .gitignore"
  git add: '.'
  git commit: "-a -m 'Initial commit'"

  if ENV['CI'] || yes?("Are you installing Shipit on a GitHub organization? (y/n)")
    org_name = ENV.fetch('GITHUB_ORGANIZATION') { ask("What is the organization name?") }
    say(
      "Shipit requires a GitHub App to authenticate users and access the API. " +
      "If you haven't created one yet, you can do so at https://github.com/organizations/#{org_name}/settings/apps/new",
      Thor::Shell::Color::GREEN, true
    )
  else
    say(
      "Shipit requires a GitHub App to authenticate users and access the API. " +
      "If you haven't created one yet, you can do so at https://github.com/settings/apps/new",
      Thor::Shell::Color::GREEN, true
    )
  end

  say("Read https://github.com/Shopify/shipit-engine/blob/main/docs/setup.md for the details on how to create the App and update config/secrets.yml", Thor::Shell::Color::GREEN, true)
end
