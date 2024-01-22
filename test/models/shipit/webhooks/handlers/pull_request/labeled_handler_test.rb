# frozen_string_literal: true

require "test_helper"

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class LabeledHandlerTest < ActiveSupport::TestCase
          test "validates payload" do
            assert_raise(StandardError) { LabeledHandler.new(payload_parsed(:invalid_pull_request)) }
          end

          test "ignores Github webhooks when the event is NOT 'labeled'" do
            assert_no_difference -> { Shipit::Stack.count } do
              LabeledHandler.new(payload_parsed(:pull_request_labeled).merge(action: "assigned")).process
            end
          end

          test "ignores Github PullRequest webhooks by default" do
            assert_no_difference -> { Shipit::Stack.count } do
              LabeledHandler.new(payload_parsed(:pull_request_with_no_repo)).process
            end
          end

          test "ignores Github PullRequest webhooks when the Repository has disabled the Review Stacks feature" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              provisioning_enabled: false,
              behavior: :allow_with_label,
              label: "pull-requests-label",
            )

            assert_no_difference -> { Shipit::Stack.count } do
              LabeledHandler.new(payload_parsed(:pull_request_labeled)).process
            end
          end

          test "ignores Github PullRequest webhooks when the repository allows_all PullRequests to create ReviewStacks" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_all,
            )

            assert_no_difference -> { Shipit::Stack.count } do
              LabeledHandler.new(payload_parsed(:pull_request_labeled)).process
            end
          end

          test "unarchives existing review stack when the repository creates ReviewStacks with allow_with_label and the label is present" do
            stack = create_archived_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] << { "name" => "pull-requests-label" }

            LabeledHandler.new(payload_parsed(:pull_request_labeled)).process

            assert_not stack.reload.archived?, "Expected stack to be NOT be archived"
            assert_pending_provision(stack)
          end

          test "creates and provisions a new review stack when the repository creates ReviewStacks with allow_with_label and the label is present" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = [{ "name" => "pull-requests-label" }]

            LabeledHandler.new(payload).process

            stack = shipit_repositories(:shipit).stacks.last
            assert_equal stack.environment, "pr#{payload['number']}"
            assert_equal stack.continuous_deployment, false
            assert_equal stack.ignore_ci, false
            assert_equal stack.branch, payload["pull_request"]["head"]["ref"]
            assert_not stack.archived?, "Expected stack to be NOT be archived"
            assert_pending_provision(stack)
          end

          test "archives an existing review stack when the repository creates ReviewStacks with allow_with_label and the label is absent" do
            stack = create_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = []

            LabeledHandler.new(payload).process

            assert stack.reload.archived?, "Expected stack to be archived"
          end

          test "deprovisions an existing review stack when the repository creates ReviewStacks with allow_with_label and the label is absent" do
            stack = create_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = []

            LabeledHandler.new(payload).process

            assert_equal stack.reload.provision_status, "deprovisioning"
          end

          test "ignores Github PullRequest webhooks when the repository allow_with_label to create ReviewStacks and the label is absent" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = []

            assert_no_difference -> { Shipit::Stack.count } do
              LabeledHandler.new(payload).process
            end
          end

          test "archives an existing review stack when the repository creates ReviewStacks with prevent_with_label and the label is present" do
            stack = create_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :prevent_with_label,
              label: "pull-requests-label",
            )

            LabeledHandler.new(payload_parsed(:pull_request_labeled)).process

            assert stack.reload.archived?, "Expected stack to be archived"
          end

          test "deprovisions an existing review stack when the repository creates ReviewStacks with prevent_with_label and the label is present" do
            stack = create_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :prevent_with_label,
              label: "pull-requests-label",
            )

            LabeledHandler.new(payload_parsed(:pull_request_labeled)).process

            assert_equal stack.reload.provision_status, "deprovisioning"
          end

          test "ignores Github PullRequest webhooks when the repository prevent_with_label to create ReviewStacks and the label is present" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :prevent_with_label,
              label: "pull-requests-label",
            )

            assert_no_difference -> { Shipit::Stack.count } do
              LabeledHandler.new(payload_parsed(:pull_request_labeled)).process
            end
          end

          test "unarchives an existing review stack when the repository creates ReviewStacks with prevent_with_label and the label is absent" do
            stack = create_archived_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :prevent_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = []

            LabeledHandler.new(payload).process

            assert_not stack.reload.archived?, "Expected stack to NOT be archived"
            assert_pending_provision(stack)
          end

          test "creates and provisions a new review stack when the repository creates ReviewStacks with prevent_with_label and the label is absent" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :prevent_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = []

            LabeledHandler.new(payload).process

            stack = shipit_repositories(:shipit).stacks.last
            assert_equal stack.environment, "pr#{payload['number']}"
            assert_equal stack.continuous_deployment, false
            assert_equal stack.ignore_ci, false
            assert_equal stack.branch, payload["pull_request"]["head"]["ref"]
            assert_not stack.archived?, "Expected stack to be NOT be archived"
            assert_pending_provision(stack)
          end

          test "assigns the PullRequest to newly created stacks" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :prevent_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] = []

            assert_difference -> { Shipit::PullRequest.count } do
              LabeledHandler.new(payload).process
            end
          end

          test "ignores Github Webhooks for closed PullRequests" do
            create_archived_stack
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository:,
              behavior: :allow_with_label,
              label: "pull-requests-label",
            )
            payload = payload_parsed(:pull_request_labeled)
            payload["pull_request"]["labels"] << { "name" => "pull-requests-label" }
            payload["pull_request"]["state"] = "closed"

            Shipit::ReviewStackProvisioningQueue.expects(:add).never

            LabeledHandler.new(payload).process
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
            stack.update(provision_status: :deprovisioned)
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

            stack = repository.review_stacks.last
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
