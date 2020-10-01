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

      # An (optional) guard to prevent provisioning. Intended to be
      # use to set logic to determine if enough actual resources exist
      # to complete the provisioning request.
      def provision?
        true
      end

      private

      attr_accessor :stack
    end
  end
end
