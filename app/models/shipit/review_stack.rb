# frozen_string_literal: true

module Shipit
  class ReviewStack < Shipit::Stack
    def self.clear_stale_caches
      Shipit::ReviewStack.where(
        "archived_since > :earliest AND archived_since < :latest",
        earliest: 1.day.ago,
        latest: 1.hour.ago
      ).find_each do |review_stack|
        review_stack.clear_local_files
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

    def update_latest_deployed_ref
      # noop: last deployed ref is useless for review stacks
    end

    model_name.class_eval do
      def route_key
        "stacks"
      end

      def singular_route_key
        "stack"
      end
    end

    has_one :pull_request, foreign_key: :stack_id

    after_commit :emit_added_hooks, on: :create
    after_commit :emit_updated_hooks, on: :update
    after_commit :emit_removed_hooks, on: :destroy

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

    def env
      return super unless pull_request.present?

      super
        .merge(
          pull_request
            .labels
            .each_with_object({}) { |label_name, labels| labels[label_name.upcase] = "true" }
        )
    end

    def provisioner
      provisioner_class.new(self)
    end

    def provisioner_class
      ProvisioningHandler.fetch(provisioning_handler_name)
    end

    def enqueue_for_provisioning
      return if awaiting_provision
      update!(awaiting_provision: true)
    end

    def remove_from_provisioning_queue
      return unless awaiting_provision
      update!(awaiting_provision: false)
    end

    def to_partial_path
      "shipit/stacks/stack"
    end

    def emit_added_hooks
      Hook.emit(:review_stack, self, action: :added, review_stack: self)
    end

    def emit_updated_hooks
      changed = !(previous_changes.keys - %w(updated_at)).empty?
      Hook.emit(:review_stack, self, action: :updated, review_stack: self) if changed
    end

    def emit_removed_hooks
      Hook.emit(:review_stack, self, action: :removed, review_stack: self)
    end
  end
end
