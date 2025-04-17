# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

Warning[:deprecated] = true if Warning.respond_to?(:[]=)

require 'simplecov'
SimpleCov.start('rails') do
  enable_coverage :branch
end

require 'webmock/minitest'

require File.expand_path('../test/dummy/config/environment.rb', __dir__)
ActiveRecord::Migrator.migrations_paths = [
  File.expand_path('../test/dummy/db/migrate', __dir__),
  File.expand_path('../db/migrate', __dir__)
]
require 'rails/test_help'
require 'mocha/minitest'
require 'spy/integration'

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_paths << File.expand_path('fixtures', __dir__)
  ActiveSupport::TestCase.fixtures(:all)
end

Dir[File.expand_path('helpers/**/*.rb', __dir__)].each do |helper|
  require helper
end

begin
  require 'pry'
rescue LoadError
end

# FIXME: We need to get rid of active_model_serializers
# This is a monkey patch for Ruby 2.7+ compatibility
module ActionController
  module SerializationAssertions
    def process(*, **)
      @serializers = Hash.new(0)
      super
    end
  end
end

module ActiveSupport
  class TestCase
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
        next if %w[@mocha @redis].include?(name)

        Shipit.remove_instance_variable(name)
      end
    end

    ActiveRecord::Migration.check_all_pending!

    fixture_paths << File.expand_path('fixtures', __dir__)

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
  end
end
