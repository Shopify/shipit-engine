require 'test_helper'

module Shipit
  class TasksTest < ActiveSupport::TestCase
    test "#title interpolates env" do
      task = shipit_tasks(:shipit_rendered_failover)
      assert_equal({'POD_ID' => '12'}, task.env)
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
  end
end
