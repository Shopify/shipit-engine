# frozen_string_literal: true

require 'test_helper'

module Shipit
  module ProvisioningHandler
    class UnregisteredProvisioningHandlerTest < ActiveSupport::TestCase
      test "#up stops transitions" do
        stack = shipit_stacks(:shipit)
        stack.update(
          provision_status: :deprovisioned,
          auto_provisioned: true
        )

        assert_throws :halt do
          UnregisteredProvisioningHandler.new(stack).up
        end
      end

      test "#up locks the stack" do
        stack = shipit_stacks(:shipit)
        stack.update(
          provision_status: :deprovisioned,
          auto_provisioned: true
        )

        assert_changes -> { stack.locked? }, from: false, to: true do
          catch :halt do
            UnregisteredProvisioningHandler.new(stack).up
          end
        end
      end

      test "#down stops transitions" do
        stack = shipit_stacks(:shipit)
        stack.update(
          provision_status: :deprovisioned,
          auto_provisioned: true
        )

        assert_throws :halt do
          UnregisteredProvisioningHandler.new(stack).down
        end
      end

      test "#down prevents transitions" do
        stack = shipit_stacks(:shipit)
        stack.update(
          provision_status: :deprovisioned,
          auto_provisioned: true
        )

        assert_changes -> { stack.locked? }, from: false, to: true do
          catch :halt do
            UnregisteredProvisioningHandler.new(stack).down
          end
        end
      end
    end
  end
end
