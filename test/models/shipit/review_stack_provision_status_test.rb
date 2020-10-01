# frozen_string_literal: true

require 'test_helper'

module Shipit
  class ReviewStackProvisionStatusTest < ActiveSupport::TestCase
    test "stacks default to deprovisioned state" do
      stack = Shipit::ReviewStack.new

      assert_equal 'deprovisioned', stack.provision_status
    end

    test "non-review stacks don't transition" do
      stack = Shipit::ReviewStack.new
      stack.provision

      assert_equal 'deprovisioned', stack.provision_status
    end

    test "review stacks that are deprovisioned can be provisioned" do
      stack = review_stack(provision_status: :deprovisioned)

      stack.provision

      assert_equal 'provisioning', stack.provision_status
    end

    test "review stacks that are provisioning can succeed" do
      stack = review_stack(provision_status: :provisioning)

      stack.provision_success

      assert_equal 'provisioned', stack.provision_status
    end

    test "review stacks that are provisioning can fail" do
      stack = review_stack(provision_status: :provisioning)

      stack.provision_failure

      assert_equal 'deprovisioned', stack.provision_status
    end

    test "review stacks are provisioned can be deprovisioned" do
      stack = review_stack(provision_status: :provisioned)

      stack.deprovision

      assert 'deprovisioning', stack.provision_status
    end

    test "review stacks that are deprovisioning can succeed" do
      stack = review_stack(provision_status: :deprovisioning)

      stack.deprovision_success

      assert_equal 'deprovisioned', stack.provision_status
    end

    test "review stacks that are deprovisioning can fail" do
      stack = review_stack(provision_status: :deprovisioning)

      stack.deprovision_failure

      assert_equal 'provisioned', stack.provision_status
    end

    def review_stack(provision_status: :deprovisioned)
      stack = shipit_stacks(:review_stack)
      stack.provision_status = provision_status

      stack.save!

      stack
    end
  end
end
