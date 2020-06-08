# frozen_string_literal: true

# frozen_string_literal: true
require 'test_helper'

module Shipit
  class StackProvisionStatusTest < ActiveSupport::TestCase
    test "stacks default to not_provisioned state" do
      stack = Shipit::Stack.new

      assert_equal 'not_provisioned', stack.provision_status
    end

    test "non-review stacks don't transition" do
      stack = Shipit::Stack.new
      stack.schedule_provision

      assert_equal 'not_provisioned', stack.provision_status
    end

    test "review stacks that have yet to be provisioned can be scheduled for provisioning" do
      stack = review_stack(provision_status: :not_provisioned)

      stack.schedule_provision

      assert_equal 'pending_provision', stack.provision_status
    end

    test "review stacks that have been scheduled for provisioning can be provisioned" do
      stack = review_stack(provision_status: :pending_provision)

      stack.provision

      assert_equal 'provisioning', stack.provision_status
    end

    test "review stacks that have been provisioning can be marked as provisioned" do
      stack = review_stack(provision_status: :provisioning)

      stack.provisioned

      assert_equal 'provisioned', stack.provision_status
    end

    test "review stacks which are provisioning can fail to provision" do
      stack = review_stack(provision_status: :provisioning)

      stack.fail_provisioning

      assert_equal 'provisioning_error', stack.provision_status
    end

    test "review stacks that have previously failed to provision can be scheduled for provisioning" do
      stack = review_stack(provision_status: :provisioning_error)

      stack.schedule_provision

      assert_equal 'pending_provision', stack.provision_status
    end

    test "review stacks that have been provisioned can be scheduled for deprovisioning" do
      stack = review_stack(provision_status: :provisioned)

      stack.schedule_deprovision

      assert_equal 'pending_deprovision', stack.provision_status
    end

    test "review stacks that have been scheduled for deprovisioning can be deprovisioned" do
      stack = review_stack(provision_status: :pending_deprovision)

      stack.deprovision

      assert_equal 'deprovisioning', stack.provision_status
    end

    test "review stacks that have been deprovisioning can be marked as deprovisioned" do
      stack = review_stack(provision_status: :deprovisioning)

      stack.deprovisioned

      assert_equal 'deprovisioned', stack.provision_status
    end

    test "review stacks that have been deprovisioning can fail deprovisioning" do
      stack = review_stack(provision_status: :deprovisioning)

      stack.fail_deprovisioning

      assert_equal 'deprovisioning_error', stack.provision_status
    end

    test "review stacks that have failed to deprovisioncan be scheduled for deprovisioning" do
      stack = review_stack(provision_status: :deprovisioning_error)

      stack.schedule_deprovision

      assert_equal 'pending_deprovision', stack.provision_status
    end

    test "review stacks that have been deprovisioned can be scheduled for provisioning" do
      stack = review_stack(provision_status: :deprovisioned)

      stack.schedule_provision

      assert_equal 'pending_provision', stack.provision_status
    end

    def review_stack(provision_status: :not_provisioned)
      stack = shipit_stacks(:shipit)
      stack.auto_provisioned = true
      stack.provision_status = provision_status

      stack.save!

      stack
    end
  end
end
