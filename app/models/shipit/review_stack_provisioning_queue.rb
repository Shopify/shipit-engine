# frozen_string_literal: true

module Shipit
  class ReviewStackProvisioningQueue
    def self.work
      new.work
    end

    PROVISIONING_QUEUED_LOCK_REASON = "This stack is in a queue waiting on " \
                                      "provisioning. This may be because too many review stacks " \
                                      "exist for this repository."

    def self.add(stack)
      stack.lock(
        PROVISIONING_QUEUED_LOCK_REASON,
        Shipit::AnonymousUser.new
      )
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
        .where(lock_reason: PROVISIONING_QUEUED_LOCK_REASON)
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
