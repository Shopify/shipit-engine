# frozen_string_literal: true

require 'test_helper'

module Shipit
  module LockProviders
    class ProviderTest < ActiveSupport::TestCase
      test "try_lock raises NotImplementedError" do
        provider = Provider.new
        assert_raises(NotImplementedError, "you must implement #try_lock") do
          provider.try_lock
        end
      end

      test "BaseProvider is abstract and cannot be instantiated directly" do
        assert_raises(NotImplementedError) do
          Provider.new.try_lock
        end
      end
    end
  end
end
