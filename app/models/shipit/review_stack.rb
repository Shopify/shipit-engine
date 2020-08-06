# frozen_string_literal: true

module Shipit
  class ReviewStack < Shipit::Stack
    state_machine :provision_status, initial: :deprovisioned do
      state :provisioned
      state :provisioning
      state :deprovisioning
      state :deprovisioned

      event :provision do
        transition deprovisioned: :provisioning
      end

      event :provision_success do
        transition provisioning: :provisioned
      end

      event :provision_failure do
        transition provisioning: :deprovisioned
      end

      event :deprovision do
        transition provisioned: :deprovisioning
      end

      event :deprovision_success do
        transition deprovisioning: :deprovisioned
      end

      event :deprovision_failure do
        transition deprovisioning: :provisioned
      end

      after_transition deprovisioned: :provisioning do |stack, _|
        stack.provisioner.up
      end

      after_transition provisioned: :deprovisioning do |stack, _|
        stack.provisioner.down
      end
    end

    def provisioner
      provisioner_class.new(self)
    end

    def provisioner_class
      ProvisioningHandler.fetch(provisioning_handler_name)
    end

    def enqueue_for_provisioning
      update!(awaiting_provision: true)
    end

    def remove_from_provisioning_queue
      update!(awaiting_provision: false)
    end

    has_one :review_request, -> { where(review_request: true) }, class_name: "MergeRequest", foreign_key: :stack_id

    def to_partial_path
      "shipit/stacks/stack"
    end

    def self.clear_stale_caches
      Shipit::ReviewStack.where(
        "archived_since > :earliest AND archived_since < :latest",
        earliest: 1.day.ago,
        latest: 1.hour.ago
      ).each do |review_stack|
        Shipit::ClearGitCacheJob.perform_later(review_stack)
      end
    end

    def self.delete_old_deployment_directories
      Shipit::Deploy.not_active.where(
        "created_at > :earliest AND updated_at < :latest",
        earliest: 1.day.ago,
        latest: 1.hour.ago
      ).find_each do |deploy|
        Shipit::Commands.for(deploy).clear_working_directory
      end
    end
  end
end
