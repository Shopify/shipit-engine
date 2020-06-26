# frozen_string_literal: true

require 'test_helper'

module Shipit
  class StackProvisioningHandlerTest < ActiveSupport::TestCase
    teardown do
      Shipit::ProvisioningHandler.reset!
    end

    test "uses default handler when no handler is registered for the stack's repository" do
      stack = shipit_stacks(:shipit)

      assert_equal Shipit::ProvisioningHandler::Base, Shipit::ProvisioningHandler.for_stack(stack)
    end

    test "allows registration of a default handler" do
      mock_handler = mock("Mock Provisioning Handler")

      Shipit::ProvisioningHandler.register(:default, mock_handler)

      assert_equal mock_handler, Shipit::ProvisioningHandler.for_stack(shipit_stacks(:shipit))
    end

    test "registers handlers at the repository level" do
      stack = shipit_stacks(:shipit)
      mock_handler = mock("Mock Provisioning Handler")

      Shipit::ProvisioningHandler.register(stack.github_repo_name, mock_handler)

      assert_equal mock_handler, Shipit::ProvisioningHandler.for_stack(stack)

      stack = shipit_stacks(:shipit_canaries)
      assert_equal mock_handler, Shipit::ProvisioningHandler.for_stack(stack)
    end

    test "handlers are called during provisioning" do
      stack = shipit_stacks(:shipit)
      stack.update(
        provision_status: :deprovisioned,
        auto_provisioned: true
      )
      mock_handler = mock("Mock Provisioning Handler")
      mock_handler.expects(:new).with(stack).returns(mock_handler)
      Shipit::ProvisioningHandler.register(stack.github_repo_name, mock_handler)

      mock_handler.expects(:up)

      assert stack.provision!, "stack should have provisioned."
    end

    test "handlers are called during deprovisioning" do
      stack = shipit_stacks(:shipit)
      stack.update(
        provision_status: :provisioned,
        auto_provisioned: true
      )
      mock_handler = mock("Mock Provisioning Handler")
      mock_handler.expects(:new).with(stack).returns(mock_handler)
      Shipit::ProvisioningHandler.register(stack.github_repo_name, mock_handler)

      mock_handler.expects(:down)

      assert stack.deprovision!, "stack should have deprovisioned."
    end
  end
end
