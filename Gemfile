source 'https://rubygems.org'

gemspec

gem 'sqlite3'
gem 'activejob-uniqueness'

group :ci do
  gem 'mysql2'
  gem 'pg'
end

group :development, :test do
  gem 'faker'
  gem 'webmock'
  gem 'rubocop'
  gem 'rubocop-shopify', require: false
end

group :test do
  gem 'libv8'
  gem 'spy'
  gem 'mocha'
  gem 'simplecov', require: false
end

group :development, :test do
  gem 'byebug'
  gem 'pry'
  gem 'mini_racer'
end

gem 'prometheus-client', '~> 2.1'
