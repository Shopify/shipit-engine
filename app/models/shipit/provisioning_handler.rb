# frozen_string_literal: true

module Shipit
  module ProvisioningHandler
    class << self
      def registry
        @registry ||= reset_registry!
      end

      def reset_registry!
        @registry = {}
      end

      def register(handler_class)
        registry[handler_class.to_s] = handler_class
      end

      def fetch(name)
        return default if name.blank?
        registry.fetch(name) { ProvisioningHandler::UnregisteredProvisioningHandler }
      end

      def default=(handler_class)
        registry[:default] = handler_class
      end

      def default
        registry.fetch(:default) { ProvisioningHandler::Base }
      end
    end
  end
end
