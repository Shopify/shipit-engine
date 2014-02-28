source 'https://rubygems.org'

gem 'rails', github: 'rails/rails', branch: '4-1-stable'
gem 'sass-rails', '~> 4.0.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.0.0'
gem 'jquery-rails'
gem 'state_machine'
gem 'resque'
gem 'resque-lock'
gem 'unicorn'
gem 'octokit'
gem 'faker'
gem 'capistrano-bundler'
gem 'capistrano-rails'
gem 'settingslogic'

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
