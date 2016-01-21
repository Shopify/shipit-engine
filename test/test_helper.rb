ENV["RAILS_ENV"] ||= "test"

require 'simplecov'
SimpleCov.start 'rails'

require 'fakeweb'
FakeWeb.allow_net_connect = false

require File.expand_path('../../test/dummy/config/environment.rb', __FILE__)
ActiveRecord::Migrator.migrations_paths = [
  File.expand_path('../../test/dummy/db/migrate', __FILE__),
  File.expand_path('../../db/migrate', __FILE__),
]
require 'rails/test_help'
require 'mocha/mini_test'
require 'spy/integration'

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
    Process.stubs(:kill)
  end

  teardown do
    Shipit.redis.flushdb
    Shipit.instance_variable_names.each do |name|
      next if name == "@mocha" || name == "@redis"
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
end
