source 'https://rubygems.org'

gemspec

gem 'mysql2'
gem 'pg'
gem 'sqlite3'

group :development, :test do
  gem 'faker'
  gem 'rubocop'
end

group :test do
  gem 'fakeweb'
  gem 'test_after_commit', '0.4.0'
  gem 'mocha'
  gem 'simplecov', require: false
end

group :debug do
  gem 'byebug'
  gem 'pry'
end
