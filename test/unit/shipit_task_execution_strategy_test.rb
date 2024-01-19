# frozen_string_literal: true

require 'test_helper'

module Shipit
  class ShipitTaskExecutionStrategyTest < ActiveSupport::TestCase
    setup do
      class FakeExecutionStrategy < Shipit::TaskExecutionStrategy::Base
        def execute; end
      end
    end

    teardown do
      Shipit.task_execution_strategy = nil

      Object.send(:remove_const, :FakeExecutionStrategy) if Object.const_defined?(:FakeExecutionStrategy)
    end

    test "uses the default strategy" do
      Shipit.task_execution_strategy = nil

      assert_equal Shipit::TaskExecutionStrategy::Default, Shipit.task_execution_strategy
    end

    test "allows registration of an execution strategy" do
      strategy = FakeExecutionStrategy

      Shipit.task_execution_strategy = strategy

      assert_equal(
        strategy,
        Shipit.task_execution_strategy,
      )
    end

    test "the registered execution strategy is invoked during execution of a task" do
      task_type = Shipit::Deploy
      task = task_type.new
      strategy = FakeExecutionStrategy
      strategy.any_instance.expects(:execute)

      Shipit.task_execution_strategy = strategy

      Shipit::PerformTaskJob.new.perform(task)
    end
  end
end
