ENV["RAILS_ENV"] ||= "test"

require 'simplecov'
SimpleCov.start 'rails'

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require "mocha/mini_test"

Dir[File.expand_path('../helpers/**/*.rb', __FILE__)].each do |helper|
  require helper
end

begin
  require 'pry'
rescue LoadError
end

class ActiveSupport::TestCase
  include PayloadsHelper
  include FixtureAliasesHelper
  include QueriesHelper
  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
