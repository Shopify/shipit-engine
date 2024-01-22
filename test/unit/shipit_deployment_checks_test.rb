# frozen_string_literal: true

require 'test_helper'

module Shipit
  class ShipitDeploymentChecksTest < ActiveSupport::TestCase
    setup do
      class FakeDeploymentChecks
        def self.call(_stack)
          true
        end
      end
    end

    teardown do
      Shipit.deployment_checks = nil

      Object.send(:remove_const, :FakeDeploymentChecks) if Object.const_defined?(:FakeDeploymentChecks)
    end

    test "allows registration of deployment checks" do
      deployment_checks = FakeDeploymentChecks

      Shipit.deployment_checks = deployment_checks

      assert_equal(
        deployment_checks,
        Shipit.deployment_checks,
      )
    end

    test "allows deployments and continuous delivery when checks are not present" do
      stack = shipit_stacks(:review_stack)
      stack.update(continuous_deployment: true)

      Shipit.deployment_checks = nil

      assert stack.deployable?

      stack.trigger_continuous_delivery

      refute stack.continuous_delivery_delayed?
    end

    test "allows deployments and continuous delivery when checks pass" do
      stack = shipit_stacks(:review_stack)
      stack.update(continuous_deployment: true)

      Shipit.deployment_checks = FakeDeploymentChecks

      assert stack.deployable?

      stack.trigger_continuous_delivery

      refute stack.continuous_delivery_delayed?
    end

    test "prevents deployments and delays continuous delivery when checks fail" do
      class FakeDeploymentChecks
        def self.call(_stack)
          false
        end
      end

      stack = shipit_stacks(:review_stack)
      stack.update(continuous_deployment: true)

      Shipit.deployment_checks = FakeDeploymentChecks

      refute stack.deployable?

      stack.trigger_continuous_delivery

      assert stack.continuous_delivery_delayed?
    end
  end
end
