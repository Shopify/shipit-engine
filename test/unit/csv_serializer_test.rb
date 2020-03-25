# typed: false
require 'test_helper'

module Shipit
  class CSVSerializerTest < ActiveSupport::TestCase
    test "blank values are dumped as nil" do
      assert_dumped nil, ''
      assert_dumped nil, '  '
      assert_dumped nil, nil
      assert_dumped nil, []
    end

    test "blank values are loaded as an empty array" do
      assert_loaded [], ''
      assert_loaded [], '  '
      assert_loaded [], nil
    end

    test "load split the words by comma" do
      assert_loaded %w(foo bar), 'foo,bar'
    end

    test "dump join the words with a comma" do
      assert_dumped 'foo,bar', %w(foo bar)
    end

    private

    def assert_dumped(expected, object)
      message = "Expected CSVSerializer.dump(#{object.inspect}) to eq #{expected.inspect}"
      if expected.nil?
        assert_nil Shipit::CSVSerializer.dump(object), message
      else
        assert_equal(expected, Shipit::CSVSerializer.dump(object), message)
      end
    end

    def assert_loaded(expected, payload)
      message = "Expected CSVSerializer.load(#{payload.inspect}) to eq #{expected.inspect}"
      if expected.nil?
        assert_nil Shipit::CSVSerializer.load(payload), message
      else
        assert_equal(expected, Shipit::CSVSerializer.load(payload), message)
      end
    end
  end
end
