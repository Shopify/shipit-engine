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

            assert_has_label stack, "expected-label"
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

            assert_has_label stack, "expected-label"
          end

          test "does not capture labels when labels are applied to archived stacks" do
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_archived_stack

            LabelCapturingHandler.new(payload).process

            assert_empty stack.reload.pull_request.labels
          end

          test "ignores unknown stacks when labels are added" do
            payload = payload_parsed(:pull_request_labeled)
            payload["repository"]["full_name"] = "unknown/repository"
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]

            assert_no_difference -> { Shipit::Stack.count } do
              LabelCapturingHandler.new(payload).process
            end
          end

          test "captures labels when labels are removed from stack which are not archived" do
            stack = create_stack
            stack.pull_request.labels << "label-to-be-removed"
            payload = payload_parsed(:pull_request_unlabeled)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]

            LabelCapturingHandler.new(payload).process

            stack.reload
            assert_does_not_have_label stack, "label-to-be-removed"
            assert_has_label stack, "expected-label"
          end

          test "does not capture labels when labels are removed from archived stacks" do
            payload = payload_parsed(:pull_request_unlabeled)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_archived_stack

            LabelCapturingHandler.new(payload).process

            assert_empty stack.reload.pull_request.labels
          end

          test "ignores unknown stacks when labels are removed" do
            payload = payload_parsed(:pull_request_unlabeled)
            payload["repository"]["full_name"] = "unknown/repository"
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]

            assert_no_difference -> { Shipit::Stack.count } do
              LabelCapturingHandler.new(payload).process
            end
          end

          test "captures labels when reopening a pull request" do
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_stack

            LabelCapturingHandler.new(payload).process

            assert_has_label stack, "expected-label"
          end

          test "does not capture labels when reopening a pull request with an archived stack" do
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]
            stack = create_archived_stack

            LabelCapturingHandler.new(payload).process

            assert_empty stack.reload.pull_request.labels
          end

          test "ignores reopening a pull request with an unknown repository" do
            payload = payload_parsed(:pull_request_reopened)
            payload["repository"]["full_name"] = "unknown/repository"
            payload["pull_request"]["labels"] = [{ "name" => "expected-label" }]

            assert_no_difference -> { Shipit::Stack.count } do
              LabelCapturingHandler.new(payload).process
            end
          end

          test "accepts extended unicode characters (emoji) in label names" do
            payload = payload_parsed(:pull_request_opened)
            payload["pull_request"]["labels"] = [{ "name" => "Shipit 🚢" }]
            stack = create_stack

            LabelCapturingHandler.new(payload).process

            assert_has_label stack, "Shipit 🚢"
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

          def assert_has_label(stack, label_name)
            assert_includes(stack.pull_request.labels, label_name)
          end

          def assert_does_not_have_label(stack, label_name)
            assert_not_includes(stack.pull_request.labels, label_name)
          end

          def environment_for(payload)
            "pr#{payload['number']}"
          end

          setup do
            Shipit.github.api.stubs(:commit)
              .with("shopify/shipit-engine", "ec26c3e57ca3a959ca5aad62de7213c562f8c821")
              .returns(
                resource(
                  {
                    sha: "ec26c3e57ca3a959ca5aad62de7213c562f8c821",
                    commit: {
                      author: {
                        name: "Codertocat",
                        email: "21031067+Codertocat@users.noreply.github.com",
                        date: "2019-05-15 15:20:30",
                      },
                      committer: {
                        name: "Codertocat",
                        email: "21031067+Codertocat@users.noreply.github.com",
                        date: "2019-05-15 15:20:30",
                      },
                      message: "Update README.md",
                    },
                    stats: {
                      total: 2,
                      additions: 1,
                      deletions: 1,
                    },
                  }
                )
              )
          end
        end
      end
    end
  end
end
