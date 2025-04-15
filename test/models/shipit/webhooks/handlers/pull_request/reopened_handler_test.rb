# frozen_string_literal: true

require "test_helper"

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class ReopenedHandlerTest < ActiveSupport::TestCase
          test "validates payload" do
            assert_raise(StandardError) { Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload_parsed(:invalid_pull_request)) }
          end

          test "ignores irrelevant PR actions" do
            assert_no_difference -> { Shipit::Stack.count } do
              Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload_parsed(:pull_request_opened).merge(action: "assigned")).process
            end
          end

          test "does not error for repos that are not tracked" do
            assert_no_difference -> { Shipit::Stack.count } do
              Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload_parsed(:pull_request_with_no_repo)).process
            end
          end

          test "de-archives stacks that were previously archived" do
            create_archived_stack

            assert_no_difference -> { Shipit::Stack.count } do
              assert_difference -> { Shipit::Stack.not_archived.count } do
                Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload_parsed(:pull_request_reopened)).process
              end
            end
          end

          test "ignored duplicate deliveries" do
            stack = create_archived_stack
            Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload_parsed(:pull_request_reopened)).process
            complete_active_tasks(stack)

            assert_no_difference -> { Shipit::Stack.not_archived.count } do
              Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload_parsed(:pull_request_reopened)).process
            end
          end

          test "unarchives stacks for repos that allow_all" do
            stack = create_archived_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_all
            )

            Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload_parsed(:pull_request_reopened)).process

            assert_not stack.reload.archived?, "Expected stack to NOT be archived"
            assert_pending_provision(stack)
          end

          test "provisions missing stacks for repos that allow_all" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_all
            )
            payload = payload_parsed(:pull_request_reopened)

            Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload).process

            stack = shipit_repositories(:shipit).stacks.last
            assert_equal stack.environment, "pr#{payload['number']}"
            assert_equal stack.continuous_deployment, false
            assert_equal stack.ignore_ci, false
            assert_equal stack.branch, payload["pull_request"]["head"]["ref"]
            assert_not stack.archived?, "Expected stack to be NOT be archived"
            assert_pending_provision(stack)
          end

          test "auto-created stack should have pull request assigned" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_all
            )
            payload = payload_parsed(:pull_request_reopened)

            assert_difference -> { Shipit::PullRequest.count } do
              Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload).process
            end
          end

          test "unarchives stacks for repos that allow_with_label when label is present" do
            stack = create_archived_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] << { "name" => "pull-requests-label" }

            Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload).process

            assert_not stack.reload.archived?, "Expected stack to be NOT be archived"
            assert_pending_provision(stack)
          end

          test "provisions missing stacks for repos that allow_with_label when label is present" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] << { "name" => "pull-requests-label" }

            Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload).process

            stack = shipit_repositories(:shipit).stacks.last
            assert_equal stack.environment, "pr#{payload['number']}"
            assert_equal stack.continuous_deployment, false
            assert_equal stack.ignore_ci, false
            assert_equal stack.branch, payload["pull_request"]["head"]["ref"]
            assert_not stack.archived?, "Expected stack to be NOT be archived"
            assert_pending_provision(stack)
          end

          test "does not unarchive stacks for repos that allow_with_label when label is absent" do
            stack = create_archived_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] = []

            Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload).process

            assert stack.reload.archived?, "Expected stack to be archived"
          end

          test "unarchives stacks for repos that prevent_with_label when label is absent" do
            stack = create_archived_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :prevent_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] = []

            Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload).process

            assert_not stack.reload.archived?, "Expected stack to be NOT be archived"
            assert_pending_provision(stack)
          end

          test "provisions missing stacks for repos that prevent_with_label when label is absent" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :prevent_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] = []

            Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload).process

            stack = shipit_repositories(:shipit).stacks.last
            assert_equal stack.environment, "pr#{payload['number']}"
            assert_equal stack.continuous_deployment, false
            assert_equal stack.ignore_ci, false
            assert_equal stack.branch, payload["pull_request"]["head"]["ref"]
            assert_not stack.archived?, "Expected stack to be NOT be archived"
            assert_pending_provision(stack)
          end

          test "does not unarchive stacks for repos that prevent_with_label when label is present" do
            stack = create_archived_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :prevent_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_reopened)
            payload["pull_request"]["labels"] << { "name" => "pull-requests-label" }

            Shipit::Webhooks::Handlers::PullRequest::ReopenedHandler.new(payload).process

            assert stack.reload.archived?, "Expected stack to be archived"
          end

          def configure_provisioning_behavior(repository:, provisioning_enabled: true, behavior: :allow_all, label: nil)
            repository.review_stacks_enabled = provisioning_enabled
            repository.provisioning_behavior = behavior
            repository.provisioning_label_name = label
            repository.save!

            repository
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

            payload = payload_parsed(:pull_request_labeled)
            payload["action"] = "opened"

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

          def assert_pending_provision(stack)
            stack.reload

            assert(stack.awaiting_provision?, "Stack #{stack.environment} should be in the provisioning queue")
            assert(stack.deprovisioned?, "Stack #{stack.environment} should be pending provision")
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
                            date: "2019-05-15 15:20:30"
                          },
                          committer: {
                            name: "Codertocat",
                            email: "21031067+Codertocat@users.noreply.github.com",
                            date: "2019-05-15 15:20:30"
                          },
                          message: "Update README.md"
                        },
                        stats: {
                          total: 2,
                          additions: 1,
                          deletions: 1
                        }
                      }
                    )
                  )
          end
        end
      end
    end
  end
end
