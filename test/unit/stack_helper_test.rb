# frozen_string_literal: true

require 'test_helper'

module Shipit
  class StackHelperTest < ActionView::TestCase
    include Shipit::StacksHelper

    def setup
      @stack = shipit_stacks(:shipit)
    end

    test "deployment_checks_message default" do
      assert_equal "Deploys have been locked by an external system", deployment_checks_message(@stack)
    end

    test "deployment_checks_message custom message" do
      module FakeDeploymentCheck
        extend self

        def call(_stack)
          false
        end

        def message(_stack)
          "test message"
        end
      end
      begin
        original_deployment_checks = Shipit.deployment_checks
        Shipit.deployment_checks = FakeDeploymentCheck
        assert_equal "test message", deployment_checks_message(@stack)
      ensure
        Shipit.deployment_checks = original_deployment_checks
      end
    end
  end
end
