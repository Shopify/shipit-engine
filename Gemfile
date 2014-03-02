source 'https://rubygems.org'

gem 'rails', github: 'rails/rails', branch: '4-1-stable'
gem 'sass-rails', '~> 4.0.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.0.0'
gem 'jquery-rails'
gem 'state_machine'
gem 'resque', '1.26.pre.0'
gem 'resque-lock'
gem 'unicorn'
gem 'octokit'
gem 'faker'
gem 'settingslogic'
gem 'omniauth'

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

if File.exist?(settings_path = File.expand_path('../config/settings.yml', __FILE__))
  require 'yaml'
  settings = YAML.load_file(settings_path)[ENV['RAILS_ENV'] || 'development']
  begin
    gem settings['authentication']['gem'] if settings['authentication']['gem']
  rescue NoMethodError
  end
end

