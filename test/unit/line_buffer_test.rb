# frozen_string_literal: true

require 'test_helper'

module Shipit
  class LineBufferTest < ActiveSupport::TestCase
    setup { @buffer = LineBuffer.new }

    test "buffers partial lines" do
      refute_predicate(@buffer.buffer("a"), :any?)
      assert_equal(["a"], @buffer.buffer("\n").to_a)
      assert_predicate(@buffer, :empty?)
    end

    test "splits up multiple lines" do
      assert_equal(%w(a b), @buffer.buffer("a\nb\n").to_a)
      assert_predicate(@buffer, :empty?)
    end
  end
end
