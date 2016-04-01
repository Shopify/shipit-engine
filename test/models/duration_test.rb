require 'test_helper'

module Shipit
  class DurationTest < ActiveSupport::TestCase
    test "#to_s is precise and readable for humans" do
      assert_equal '1m01s', Duration.new(61).to_s
      assert_equal '1m00s', Duration.new(60).to_s
      assert_equal '59s', Duration.new(59).to_s
      assert_equal '2d00h00m00s', Duration.new(2.days).to_s
      assert_equal '0s', Duration.new(0).to_s
    end
  end
end
