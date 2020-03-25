# typed: false
require 'test_helper'

module Shipit
  class DurationTest < ActiveSupport::TestCase
    test "#<=> allow comparisons" do
      assert_equal Duration.new(1), Duration.new(1)
      assert Duration.new(2) > Duration.new(1)
      assert Duration.new(2) > 1
      assert 1 < Duration.new(2)
    end

    test "can be added to a Time instance" do
      assert_equal Time.at(42), Time.at(40) + Duration.new(2)
    end

    test "#to_s is precise and readable for humans" do
      assert_equal '1m01s', Duration.new(61).to_s
      assert_equal '1m00s', Duration.new(60).to_s
      assert_equal '59s', Duration.new(59).to_s
      assert_equal '2d00h00m00s', Duration.new(2.days).to_s
      assert_equal '0s', Duration.new(0).to_s
    end

    test ".parse can read human format" do
      assert_equal Duration.new(61), Duration.parse('1m01s')
      assert_equal Duration.new(60), Duration.parse('1m00s')
      assert_equal Duration.new(59), Duration.parse('59s')
      assert_equal Duration.new(2.days), Duration.parse('2d00h00m00s')
      assert_equal Duration.new(0), Duration.parse('0s')
    end

    test ".parse accepts integers as seconds" do
      assert_equal Duration.new(42), Duration.parse(42)
    end
  end
end
