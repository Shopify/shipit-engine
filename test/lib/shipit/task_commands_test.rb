# frozen_string_literal: true

require "test_helper"

class TaskCommandsTest < ActiveSupport::TestCase
  test "#env includes a ReviewStack's pull request labels" do
    stack = shipit_stacks(:review_stack)
    stack.pull_request.labels = [
      Shipit::Label.find_or_create_by(name: "wip"),
      Shipit::Label.find_or_create_by(name: "bug"),
    ]
    task = shipit_tasks(:shipit_restart)
    task.stack = stack

    env = Shipit::TaskCommands.new(task).env

    assert_equal env["WIP"], "true"
    assert_equal env["BUG"], "true"
  end
end
