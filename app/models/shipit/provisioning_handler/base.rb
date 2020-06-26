# frozen_string_literal: true

module Shipit
  module ProvisioningHandler
    class Base
      def initialize(stack)
        @stack = stack
      end

      def up
        # Intentionally a noop
      end

      def down
        # Intentionally a noop
      end

      private

      attr_accessor(
        :stack,
      )
    end
  end
end
