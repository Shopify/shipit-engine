source 'https://rubygems.org'

gemspec

gem 'mysql2'
gem 'pg'
gem 'sqlite3'

group :development do
  gem 'sucker_punch'
end

group :development, :test do
  gem 'faker'
  gem 'fakeweb'
  gem 'rubocop'
end

group :test do
  gem 'test_after_commit', '0.4.0'
  gem 'mocha'
  gem 'simplecov', require: false
end

group :debug do
  gem 'byebug'
  gem 'pry'
end
