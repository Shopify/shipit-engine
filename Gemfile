source 'https://rubygems.org'

gemspec

gem 'redis', '~> 3.2' # 3.3 breaks the test suite because it uses `Timeout.timeout`
gem 'mysql2'
gem 'pg'
gem 'sqlite3'
gem 'therubyracer', platform: :ruby

group :development do
  gem 'sucker_punch', require: %w(sucker_punch sucker_punch/async_syntax)
end

group :development, :test do
  gem 'faker'
  gem 'fakeweb'
  gem 'rubocop', '0.34.0'
end

group :test do
  gem 'spy'
  gem 'test_after_commit'
  gem 'mocha'
  gem 'simplecov', require: false
end

group :debug do
  gem 'byebug'
  gem 'pry'
end
