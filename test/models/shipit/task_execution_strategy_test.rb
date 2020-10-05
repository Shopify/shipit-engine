# frozen_string_literal: true

require 'test_helper'

module Shipit
  class TaskExecutionStrategyTest < ActiveSupport::TestCase
    setup do
      class FakeExecutionStrategy < Shipit::TaskExecutionStrategy::Base
        def execute; end
      end
    end

    teardown do
      Shipit::TaskExecutionStrategy.reset_registry!

      Object.send(:remove_const, :FakeExecutionStrategy) if Object.const_defined?(:FakeExecutionStrategy)
    end

    test "uses the default strategy as default when no default handler is registered" do
      assert_equal Shipit::TaskExecutionStrategy::Default, Shipit::TaskExecutionStrategy.default
    end

    test "allows registration of a default strategy" do
      strategy = FakeExecutionStrategy

      Shipit::TaskExecutionStrategy.default = strategy

      assert_equal(
        strategy,
        Shipit::TaskExecutionStrategy.default
      )
    end

    test "default execution strategy is used when a strategy hasn't been provided for the task type" do
      task = Shipit::Deploy.new

      assert_instance_of(
        Shipit::TaskExecutionStrategy.default,
        Shipit::TaskExecutionStrategy.for(task)
      )
    end

    test "registers execution strategies for task types" do
      strategy = FakeExecutionStrategy
      task_type = Shipit::Deploy
      task = task_type.new

      Shipit::TaskExecutionStrategy.register(task_type, strategy)

      assert_instance_of strategy, Shipit::TaskExecutionStrategy.for(task)
    end

    test "the registered execution strategy is invoked during execution of the task" do
      task_type = Shipit::Deploy
      task = task_type.new
      strategy = FakeExecutionStrategy
      Shipit::TaskExecutionStrategy.register(task_type, strategy)

      strategy.any_instance.expects(:execute)

      Shipit::PerformTaskJob.new.perform(task)
    end
  end
end
