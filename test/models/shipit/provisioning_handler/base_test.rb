# frozen_string_literal: true

require 'test_helper'

module Shipit
  module ProvisioningHandler
    class BaseTest < ActiveSupport::TestCase
      test "provides a default #up handler" do
        assert(
          handler.respond_to?(:up),
          "expected #{handler.class.name} to provide a default #up handler",
        )
      end

      test "provides a default #down handler" do
        assert(
          handler.respond_to?(:down),
          "expected #{handler.class.name} to provide a default #down handler",
        )
      end

      test "provides a default #provision? handler" do
        assert_equal true, handler.provision?
      end

      private

      def handler
        ProvisioningHandler::Base.new(mock("Stack"))
      end
    end
  end
end
