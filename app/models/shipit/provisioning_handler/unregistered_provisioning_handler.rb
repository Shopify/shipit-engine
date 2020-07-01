# frozen_string_literal: true

module Shipit
  module ProvisioningHandler
    class UnregisteredProvisioningHandler < Shipit::ProvisioningHandler::Base
      def up
        lock_and_prevent_transition
      end

      def down
        lock_and_prevent_transition
      end

      private

      def lock_and_prevent_transition
        stack.lock(
          "Failed to find a provisioning handler named '#{stack.provisioning_handler_name}' in the " \
          "ProvisioningHandler registry. Have you registered it via Provisioning::Handler.register?",
          Shipit::AnonymousUser.new
        )
        throw(:halt)
      end
    end
  end
end
