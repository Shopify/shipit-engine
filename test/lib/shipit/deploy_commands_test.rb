# frozen_string_literal: true

require "test_helper"

class DeployCommandsTest < ActiveSupport::TestCase
  test "#env includes the stack's pull request labels" do
    stack = shipit_stacks(:review_stack)
    stack.pull_request.labels = [
      Shipit::Label.find_or_create_by(name: "wip"),
      Shipit::Label.find_or_create_by(name: "bug"),
    ]
    deploy = stack.trigger_continuous_delivery

    env = Shipit::DeployCommands.new(deploy).env

    assert_equal env["WIP"], "true"
    assert_equal env["BUG"], "true"
  end
end
