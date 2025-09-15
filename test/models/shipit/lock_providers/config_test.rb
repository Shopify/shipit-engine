# frozen_string_literal: true

require 'test_helper'

module Shipit
  module LockProviders
    class ConfigTest < ActiveSupport::TestCase
      class TestProvider < Provider
        def try_lock
          nil
        end
      end

      def setup
        @original_config = Config.config
        Config.instance_variable_set(:@config, nil)
      end

      def teardown
        Config.instance_variable_set(:@config, @original_config)
      end

      test "configure creates a new config instance with default provider" do
        config = Config.configure do |c|
          c.provider = TestProvider
        end
        assert_equal TestProvider, config.provider
      end
    end
  end
end
