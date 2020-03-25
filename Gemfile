source 'https://rubygems.org'

gemspec

gem 'sqlite3'
gem 'sorbet-runtime'

group :ci do
  gem 'mysql2'
  gem 'pg'
end

group :development, :test do
  gem 'faker'
  gem 'webmock'
  gem 'rubocop', '~> 0.52.0'
  gem 'sorbet' # Provides the static checker and the `srb` tool
end

group :test do
  gem 'spy'
  gem 'mocha'
  gem 'simplecov', require: false
end

group :development, :test do
  gem 'byebug'
  gem 'pry'
end
