# frozen_string_literal: true

require 'test_helper'

module Shipit
  class StackProvisioningHandlerTest < ActiveSupport::TestCase
    teardown do
      Shipit::ProvisioningHandler.reset_registry!
    end

    test "uses the no-op handler as default when no default handler is registered" do
      assert_equal Shipit::ProvisioningHandler::Base, Shipit::ProvisioningHandler.default
    end

    test "allows registration of a default handler" do
      mock_handler = mock("Mock Provisioning Handler")

      Shipit::ProvisioningHandler.default = mock_handler

      assert_equal mock_handler, Shipit::ProvisioningHandler.default
    end

    test "UnregisteredProvisioningHandler is returned when an attempt to fetch an unregistered handler is made" do
      unregistered_handler = mock("Mock Provisioning Handler")

      assert_equal(
        Shipit::ProvisioningHandler::UnregisteredProvisioningHandler,
        Shipit::ProvisioningHandler.fetch(unregistered_handler),
      )
    end

    test "registers handlers so they become fetchable" do
      mock_handler = mock("Mock Provisioning Handler")

      Shipit::ProvisioningHandler.register(mock_handler)

      assert_equal mock_handler, Shipit::ProvisioningHandler.fetch(mock_handler.to_s)
    end

    test "handlers are called during provisioning" do
      stack = shipit_stacks(:review_stack)
      stack.update(
        provision_status: :deprovisioned,
      )
      handler = Shipit::ProvisioningHandler.default

      handler.any_instance.expects(:up)

      assert stack.provision!, "stack should have provisioned."
    end

    test "handlers are called during deprovisioning" do
      stack = shipit_stacks(:review_stack)
      stack.update(
        provision_status: :provisioned,
      )
      handler = Shipit::ProvisioningHandler.default

      handler.any_instance.expects(:down)

      assert stack.deprovision!, "stack should have deprovisioned."
    end
  end
end
