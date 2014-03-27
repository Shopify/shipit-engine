source 'https://rubygems.org'

gem 'rails', '4.1.0.rc2'
gem 'sass-rails', '~> 4.0.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.0.0'
gem 'jquery-rails'
gem 'state_machine'
gem 'resque', '1.26.pre.0'
gem 'resque-workers-lock', require: 'resque/plugins/workers/lock'
gem 'redis-rails'
gem 'unicorn'
gem 'octokit'
gem 'faker'
gem 'settingslogic'
gem 'omniauth'
gem 'omniauth-google-apps'
gem 'safe_yaml', require: 'safe_yaml/load'
gem 'airbrake'

group :production do
  gem 'mysql2'
end

group :development, :test do
  gem 'unicorn-rails'
  gem 'sqlite3'
end

group :test do
  gem 'mocha'
end

group :debug do
  gem 'byebug'
  gem 'pry'
end

group :deploy do
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
end

