# frozen_string_literal: true
require 'test_helper'

module Shipit
  class TasksTest < ActiveSupport::TestCase
    test "#title interpolates env" do
      task = shipit_tasks(:shipit_rendered_failover)
      assert_equal({ 'POD_ID' => '12' }, task.env)
      assert_equal 'Failover pod 12', task.title
    end

    test "#title returns the task action if title is not defined" do
      task = shipit_tasks(:shipit_restart)
      assert_equal 'Restart application', task.title
    end

    test '#title returns an error message when the title raises an error' do
      task = shipit_tasks(:shipit_with_title_parsing_issue)
      assert_equal 'This task (title: Using the %{WRONG_VARIABLE_NAME}) cannot be shown due to an incorrect variable name. Check your shipit.yml file', task.title
    end

    test "#write sends line-buffered output to task logger" do
      task = shipit_tasks(:shipit)

      mock_task_logger = mock.tap do |m|
        m.expects(:info).with("[shipit-engine#1] hello").once
        m.expects(:info).never
      end

      Shipit.stubs(:task_logger).returns(mock_task_logger)

      task.write("hello\nworld")
    end

    test "#chunk_output truncates output exceeding the storage limit" do
      task = shipit_tasks(:shipit)
      Shipit.redis.del(task.output_key)

      task.write('a' * (Task::OUTPUT_SIZE_LIMIT * 1.1))

      output = task.chunk_output

      assert output.size <= Task::OUTPUT_SIZE_LIMIT, "Output was not truncated to the limit"
      # We don't use assert_includes because it will print the whole message
      assert(
        output.include?(Task::OUTPUT_TRUNCATED_MESSAGE),
        "'#{Task::OUTPUT_TRUNCATED_MESSAGE.chomp}' was not present in the output",
      )
    end

    test "#retry_if_necessary creates a duplicated task object with pending status and nil created_at and ended_at" do
      task = shipit_tasks(:shipit)
      task_stack = task.stack
      task.retry_if_necessary

      retried_task = task_stack.deploys.last

      assert_not_equal task.id, retried_task.id
      assert_nil retried_task.started_at
      assert_nil retried_task.ended_at
      assert_equal 'pending', retried_task.status
    end

    test "#retry_if_necessary does not create a new task object if max_retries is nil" do
      task = shipit_tasks(:shipit2)

      assert_no_difference 'Task.count', 'No new task should be created' do
        task.retry_if_necessary
      end
    end

    test "#retry_if_necessary does not create a new task object if the stack is locked" do
      task = shipit_tasks(:shipit2)
      task.stack.lock("test", task.user)

      assert_no_difference 'Task.count', 'No new task should be created' do
        task.retry_if_necessary
      end
    end

    test "#retries_configured? returns true when max_retries is not nil and is greater than zero" do
      task_with_three_retries = shipit_tasks(:shipit)
      assert_predicate task_with_three_retries, :retries_configured?

      task_with_nil_retries = shipit_tasks(:shipit2)
      refute_predicate task_with_nil_retries, :retries_configured?

      task_with_zero_retries = shipit_tasks(:shipit_restart)
      refute_predicate task_with_zero_retries, :retries_configured?
    end
  end
end
