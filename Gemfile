source 'https://rubygems.org'

gemspec

gem 'sqlite3'

group :ci do
  gem 'mysql2'
  gem 'pg'
end

group :development, :test do
  gem 'faker'
  gem 'fakeweb'
  gem 'rubocop', '~> 0.52.0'
end

group :test do
  gem 'spy'
  gem 'mocha'
  gem 'timecop'
  gem 'simplecov', require: false
end

group :development, :test do
  gem 'byebug'
  gem 'pry'
end
