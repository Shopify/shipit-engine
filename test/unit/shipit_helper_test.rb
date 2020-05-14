# frozen_string_literal: true
require 'test_helper'

module Shipit
  class ShipitHelperTest < ActionView::TestCase
    include Shipit::ShipitHelper
    include ERB::Util

    test "#emojify embeds known emojis" do
      assert_includes emojify(':smile:'), '<img'
    end

    test "#emojify returns unknown emojis" do
      assert_equal ':unknown:', emojify(':unknown:')
    end
  end
end
