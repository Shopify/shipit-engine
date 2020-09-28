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

        # Prevent transition of the ReviewStack 'provision_status'
        # state machine. This signals to the state_machines gem that
        # the transition should be canceled.
        #
        # References:
        #
        #  - https://github.com/state-machines/state_machines/blob/309668998449ca6c348de809f34660d822bc626e/lib/state_machines/callback.rb#L81-L89
        #  - https://github.com/state-machines/state_machines/blob/309668998449ca6c348de809f34660d822bc626e/lib/state_machines/transition_collection.rb#L63
        throw(:halt)
      end
    end
  end
end
