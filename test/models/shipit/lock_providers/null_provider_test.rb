# frozen_string_literal: true

require 'test_helper'

module Shipit
  module LockProviders
    class NullProviderTest < ActiveSupport::TestCase
      test "try_lock returns nil" do
        assert_nil NullProvider.new.try_lock
      end
    end
  end
end
