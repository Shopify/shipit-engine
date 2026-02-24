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
        Shipit.task_execution_strategy
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

  class DefaultTaskExecutionStrategyDryRunTest < ActiveSupport::TestCase
    setup do
      @task = mock('task')
      @commands = mock('commands')
      @install_deps = [mock('install_dep_cmd')]
      @perform_cmds = [mock('perform_cmd')]
      @commands.stubs(:install_dependencies).returns(@install_deps)
      @commands.stubs(:perform).returns(@perform_cmds)
      Shipit::Commands.stubs(:for).with(@task).returns(@commands)

      @strategy = Shipit::TaskExecutionStrategy::Default.new(@task)
    end

    teardown do
      ENV.delete('SHIPIT_DRY_RUN')
    end

    test "perform_task runs both install_dependencies and perform when SHIPIT_DRY_RUN is not set" do
      @strategy.instance_variable_set(:@commands, @commands)
      @strategy.expects(:capture_all!).with(@install_deps).once
      @strategy.expects(:capture_all!).with(@perform_cmds).once

      @strategy.perform_task
    end

    test "perform_task skips perform when SHIPIT_DRY_RUN is set" do
      ENV['SHIPIT_DRY_RUN'] = '1'

      @strategy.instance_variable_set(:@commands, @commands)
      @strategy.expects(:capture_all!).with(@install_deps).once
      @strategy.expects(:capture_all!).with(@perform_cmds).never
      @task.expects(:write).with("\nSkipping deploy steps (dry run mode)\n")

      @strategy.perform_task
    end
  end
end
