# frozen_string_literal: true

module Shipit
  class ReviewStackProvisioningQueue
    def self.work
      new.work
    end

    def self.add(stack)
      stack.enqueue_for_provisioning
    end

    def self.queued_stacks
      new.queued_stacks
    end

    def work
      queued_stacks.find_each(&method(:provision))
    end

    def queued_stacks
      @queued_stacks ||= Shipit::ReviewStack
                         .with_provision_status(:deprovisioned)
                         .where(awaiting_provision: true)
    end

    private

    def provision(stack)
      if stack.provisioner.provision?
        stack.provision
      else
        Rails.logger.info(
          "Putting review ReviewStack<#{stack.id}> back into the provisioning queue - #provision? was falsey."
        )
      end
    end
  end
end
