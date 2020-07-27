# frozen_string_literal: true

require "test_helper"

module Shipit
  class ReviewStackProvisioningQueueTest < ActiveSupport::TestCase
    test ".add en-queues a stack for provisioning" do
      review_stack = shipit_stacks(:review_stack)
      review_stack.update(lock_reason: nil)

      assert_changes -> { review_stack.lock_reason }, from: nil, to: provisioning_enqueued_lock_reason do
        queue.add(review_stack)
      end
    end

    test ".work provisions resource stacks when they are provision-able" do
      review_stack = provisionable_review_stack
      setup_provisioning_handler(for_stack: review_stack, provision: true)
      queue.add(review_stack)

      assert_changes -> { review_stack.reload.provision_status }, from: "deprovisioned", to: "provisioning" do
        queue.work
      end
    end

    test ".work does not provision resource stacks when they are not provisionable" do
      review_stack = provisionable_review_stack
      setup_provisioning_handler(for_stack: review_stack, provision: false)
      queue.add(review_stack)

      assert_equal "deprovisioned", review_stack.provision_status
      assert_no_changes -> { review_stack.reload.provision_status } do
        queue.work
      end
    end

    private

    def setup_provisioning_handler(for_stack:, provision:)
      provisioning_handler_instance = mock("ProvisioningHandler instance")
      provisioning_handler_instance.expects(:provision?).returns(provision)
      provisioning_handler_instance.expects(:up).returns(true) if !!provision
      provisioning_handler_class = mock("ProvisioningHandler class")
      provisioning_handler_class.expects(:new).at_least_once.with(for_stack).returns(provisioning_handler_instance)
      Shipit::ProvisioningHandler.expects(:fetch).at_least_once.returns(provisioning_handler_class)

      provisioning_handler_instance
    end

    def provisionable_review_stack
      review_stack = shipit_stacks(:review_stack)
      review_stack.update(
        provision_status: :deprovisioned,
      )

      review_stack
    end

    def queue
      ReviewStackProvisioningQueue
    end

    def provisioning_enqueued_lock_reason
      queue::PROVISIONING_QUEUED_LOCK_REASON
    end
  end
end
