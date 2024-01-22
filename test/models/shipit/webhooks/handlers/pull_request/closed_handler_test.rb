# frozen_string_literal: true

require "test_helper"

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class ClosedHandlerTest < ActiveSupport::TestCase
          test "validates payload" do
            assert_raise(StandardError) { Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload_parsed(:invalid_pull_request)) }
          end

          test "ignores irrelevant PR actions" do
            assert_no_difference -> { Shipit::Stack.not_archived.count } do
              Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload_parsed(:pull_request_opened).merge(action: "assigned")).process
            end
          end

          test "does not error for repos that are not tracked" do
            Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload_parsed(:pull_request_with_no_repo).merge(action: "closed")).process
          end

          test "archives stacks for repos that are tracked" do
            create_stack
            assert_difference -> { Shipit::Stack.not_archived.count }, -1 do
              Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload_parsed(:pull_request_closed)).process
            end
          end

          test "ignored duplicate deliveries" do
            Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload_parsed(:pull_request_opened)).process
            Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload_parsed(:pull_request_closed)).process
            assert_no_difference -> { Shipit::Stack.not_archived.count } do
              Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload_parsed(:pull_request_closed)).process
            end
          end

          test "archives stacks for repos that allow_all" do
            stack = create_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :allow_all,
            )

            Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload_parsed(:pull_request_closed)).process

            assert stack.reload.archived?, "Expected stack to be archived"
          end

          test "archives stacks for repos that allow_with_label when label is present" do
            stack = create_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :allow_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_closed)
            payload["pull_request"]["labels"] << { "name" => "pull-requests-label" }

            Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload).process

            assert stack.reload.archived?, "Expected stack to be archived"
          end

          test "archives stacks for repos that allow_with_label when label is absent" do
            stack = create_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :allow_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_closed)
            payload["pull_request"]["labels"] = []

            Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload).process

            assert stack.reload.archived?, "Expected stack to be archived"
          end

          test "archives stacks for repos that prevent_with_label when label is absent" do
            stack = create_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :prevent_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_closed)
            payload["pull_request"]["labels"] = []

            Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload).process

            assert stack.reload.archived?, "Expected stack to be archived"
          end

          test "archives stacks for repos that prevent_with_label when label is present" do
            stack = create_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :prevent_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_closed)
            payload["pull_request"]["labels"] << { "name" => "pull-requests-label" }

            Shipit::Webhooks::Handlers::PullRequest::ClosedHandler.new(payload).process

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
            stack.update(provision_status: :provisioned)
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
                  },
                ),
              )
          end
        end
      end
    end
  end
end
