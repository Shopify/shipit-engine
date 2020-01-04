ENV["RAILS_ENV"] ||= "test"

require 'simplecov'
SimpleCov.start 'rails'

require 'webmock/minitest'

require File.expand_path('../../test/dummy/config/environment.rb', __FILE__)
ActiveRecord::Migrator.migrations_paths = [
  File.expand_path('../../test/dummy/db/migrate', __FILE__),
  File.expand_path('../../db/migrate', __FILE__),
]
require 'rails/test_help'
require 'mocha/minitest'
require 'spy/integration'
require 'faker'

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
  ActiveSupport::TestCase.fixtures :all
end

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
  include JSONHelper
  include LinksHelper
  include ApiHelper
  include HooksHelper
  include ActiveJob::TestHelper

  setup do
    @routes = Shipit::Engine.routes
    Shipit.github.api.stubs(:login).returns('shipit')
  end

  teardown do
    Shipit.redis.flushdb
    Shipit.instance_variable_names.each do |name|
      next if %w(@mocha @redis).include?(name)
      Shipit.remove_instance_variable(name)
    end
  end

  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
  private

  def resource(data)
    Sawyer::Resource.new(Sawyer::Agent.new('http://example.com'), data)
  end

  # assert if two list of objets are similar based on the keys you want to compare
  def assert_object_keys(expected, actual, *attr)
    expected_hash = expected.map do |item|
       attributes = item.attributes.symbolize_keys
       attributes = attributes.extract!(*attr) unless attr.nil?
       attributes
    end

    actual_hash = actual.map do |item|
      attributes = item.attributes.symbolize_keys
      attributes = attributes.extract!(*attr) unless attr.nil?
      attributes
    end

    assert_equal expected_hash, actual_hash
  end
end
