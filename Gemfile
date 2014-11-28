source 'https://rubygems.org'

gem 'rails', '~> 4.2.0.rc1', github: 'rails/rails', branch: '4-2-stable', ref: '406c9082782d9a9cd3cd8a835e41632524b79544'
gem 'responders'
gem 'sprockets'
gem 'mysql2'
gem 'sass-rails'
gem 'uglifier'
gem 'coffee-rails'
gem 'jquery-rails'
gem 'state_machine'
gem 'resque', '1.26.pre.0'
gem 'resque-workers-lock', require: 'resque/plugins/workers/lock'
gem 'redis-rails'
gem 'thin'
gem 'octokit'
gem 'faker'
gem 'omniauth'
gem 'omniauth-github'
gem 'omniauth-google-oauth2'
gem 'safe_yaml', require: 'safe_yaml/load'
gem 'airbrake', '~> 3.1.5'
gem 'pubsubstub', '~> 0.0.7'
gem 'securecompare', '~>1.0'
gem 'rails-timeago', '~> 2.0'
gem 'ansi_stream', '~> 0.0.3'
gem 'heroku'
gem 'faraday'
gem 'validate_url'

group :development do
  gem 'quiet_assets'
end

group :development, :test do
  gem 'foreman', '~> 0.74'
  gem 'rubocop'
end

group :test do
  gem 'test_after_commit'
  gem 'mocha'
  gem 'simplecov', require: false
end

group :debug do
  gem 'byebug'
  gem 'pry'
end

group :deploy do
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano', '3.1.0'
  gem 'whenever'
end
