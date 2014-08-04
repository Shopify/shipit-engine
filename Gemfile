source 'https://rubygems.org'

gem 'rails', '4.1.1'
gem 'sass-rails'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails'
gem 'jquery-rails'
gem 'state_machine'
gem 'resque', '1.26.pre.0'
gem 'resque-workers-lock', require: 'resque/plugins/workers/lock'
gem 'redis-rails'
gem 'thin'
gem 'octokit'
gem 'faker'
gem 'settingslogic'
gem 'omniauth'
gem 'omniauth-github'
gem 'omniauth-google-oauth2'
gem 'safe_yaml', require: 'safe_yaml/load'
gem 'airbrake', '~> 3.1.5'
gem 'pubsubstub', '~> 0.0.7'
gem 'securecompare', '~>1.0'
gem 'rails-timeago', '~> 2.0'
gem 'ansi_stream', '~> 0.0.3'
gem 'heroku', '~> 3.8.2'
gem 'whenever'

group :production do
  gem 'mysql2'
end

group :development, :test do
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

