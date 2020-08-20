# frozen_string_literal: true

require "test_helper"

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class LabelCapturingHandlerTest < ActiveSupport::TestCase
          test "captures labels when opening a pull request for a known stack" do
            payload = payload_parsed(:pull_request_opened)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_stack

            LabelCapturingHandler.new(payload).process

            assert_has_label_variable stack, "expected-label"
          end

          test "does not create stacks when opening new pull requests" do
            payload = payload_parsed(:pull_request_opened)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]

            assert_no_difference -> { Shipit::Stack.count } do
              LabelCapturingHandler.new(payload).process
            end
          end

          test "captures labels when labels are applied to stacks which are not archived" do
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_stack

            LabelCapturingHandler.new(payload).process

            assert_has_label_variable stack, "expected-label"
          end

          test "does not capture labels when labels are applied to archived stacks" do
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_archived_stack

            LabelCapturingHandler.new(payload).process

            assert_empty stack.reload.pull_request.labels
          end

          test "does not create labels for unknown stacks when labels are added" do
            payload = payload_parsed(:pull_request_labeled)
            payload["repository"]["full_name"] = "unknown/repository"
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]

            assert_no_difference -> { Shipit::Stack.count } do
              assert_no_difference -> { Shipit::PullRequestLabel.count } do
                LabelCapturingHandler.new(payload).process
              end
            end
          end

          test "captures labels when labels are removed from stack which are not archived" do
            stack = create_stack
            stack.pull_request.labels << Shipit::Label.find_or_create_by(name: "label-to-be-removed")
            payload = payload_parsed(:pull_request_unlabeled)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]

            LabelCapturingHandler.new(payload).process

            stack.reload
            assert_does_not_have_label stack, "label-to-be-removed"
            assert_has_label_variable stack, "expected-label"
          end

          test "does not capture labels when labels are removed from archived stacks" do
            payload = payload_parsed(:pull_request_unlabeled)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_archived_stack

            LabelCapturingHandler.new(payload).process

            assert_empty stack.reload.pull_request.labels
          end

          test "does not create labels for unknown stacks when labels are removed" do
            payload = payload_parsed(:pull_request_unlabeled)
            payload["repository"]["full_name"] = "unknown/repository"
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]

            assert_no_difference -> { Shipit::Stack.count } do
              assert_no_difference -> { Shipit::PullRequestLabel.count } do
                LabelCapturingHandler.new(payload).process
              end
            end
          end

          test "captures labels when reopening a pull request" do
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_stack

            LabelCapturingHandler.new(payload).process

            assert_has_label_variable stack, "expected-label"
          end

          test "does not capture labels when reopening a pull request with an archived stack" do
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_archived_stack

            LabelCapturingHandler.new(payload).process

            assert_empty stack.reload.pull_request.labels
          end

          test "does not capture labels when reopening a pull request with an unknown repository" do
            payload = payload_parsed(:pull_request_reopened)
            payload["repository"]["full_name"] = "unknown/repository"
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]

            assert_no_difference -> { Shipit::Stack.count } do
              assert_no_difference -> { Shipit::PullRequestLabel.count } do
                LabelCapturingHandler.new(payload).process
              end
            end
          end

          test "accepts extended unicode characters (emoji) in label names" do
            payload = payload_parsed(:pull_request_opened)
            payload["pull_request"]["labels"] = [{ "name" => "Shipit 🚢" }]
            stack = create_stack

            LabelCapturingHandler.new(payload).process

            assert_has_label_variable stack, "Shipit 🚢"
          end

          def create_archived_stack
            stack = create_stack
            stack.archive!(shipit_users(:codertocat))

            stack
          end

          def create_stack
            repository = shipit_repositories(:shipit)
            repository.provisioning_behavior = :allow_all
            repository.save!

            payload = payload_parsed(:pull_request_opened)

            OpenedHandler.new(payload).process

            stack = repository.stacks.last
            complete_active_tasks(stack)

            stack
          end

          def complete_active_tasks(stack)
            active_tasks = stack
              .tasks
              .active

            active_tasks.map(&:run)
            active_tasks.reload
            active_tasks.map(&:complete)
          end

          def assert_has_label_variable(stack, label_name)
            assert_includes(stack.pull_request.labels.pluck(:name), label_name)
          end

          def assert_does_not_have_label(stack, label_name)
            assert_not_includes(stack.pull_request.labels.pluck(:name), label_name)
          end

          def environment_for(payload)
            "pr#{payload['number']}"
          end
        end
      end
    end
  end
end
