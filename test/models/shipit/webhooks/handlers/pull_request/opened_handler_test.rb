# frozen_string_literal: true

require "test_helper"

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class OpenedHandlerTest < ActiveSupport::TestCase
          test "validates payload" do
            assert_raise(StandardError) { OpenedHandler.new(payload_parsed(:invalid_pull_request)) }
          end

          test "ignores irrelevant PR actions" do
            assert_no_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload_parsed(:pull_request_opened).merge(action: "assigned")).process
            end
          end

          test "does not create stacks for repos that are not tracked" do
            assert_no_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload_parsed(:pull_request_with_no_repo)).process
            end
          end

          test "does not create a stack when the Pull Request data can be saved" do
            Shipit::PullRequest
              .any_instance
              .expects(:update!)
              .raises(ActiveRecord::StatementInvalid)

            assert_no_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload_parsed(:pull_request_opened)).process
            rescue ActiveRecord::StatementInvalid # We expect this to be raised, so it shouldn't fail the test
            end
          end

          test "creates stacks for repos that are tracked" do
            assert_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload_parsed(:pull_request_opened)).process
            end
          end

          test "creates Shipit::Users when they're not already present" do
            github_user = stub(
              id: 42,
              name: "Somenew Userlogin",
              login: "some-new-user-login",
              email: "somenewuser@login.com",
              avatar_url: "https://avatars.githubusercontent.com/u/42?v=3",
              url: "https://api.github.com/user/some-new-user-login"
            )
            Shipit.github.api.expects(:user).with("some-new-user-login")
              .returns(github_user)
            payload = payload_parsed(:pull_request_opened)
            payload["pull_request"]["user"]["login"] = github_user.login

            OpenedHandler.new(payload).process

            user = Shipit::User.find_by(login: "some-new-user-login")
            assert_equal github_user.login, user.login
            assert_equal github_user.name, user.name
            assert_equal github_user.email, user.email
            assert_equal github_user.url, user.api_url
            assert_equal github_user.avatar_url, user.avatar_url
          end

          test "does not create Shipit::Users when they're already present" do
            payload = payload_parsed(:pull_request_opened)
            user_login = payload["pull_request"]["user"]["login"]

            assert_no_difference -> { Shipit::User.where(login: user_login).count } do
              OpenedHandler.new(payload).process
            end
          end

          test "auto-created stack should have default configuration values" do
            payload = payload_parsed(:pull_request_opened)
            OpenedHandler.new(payload).process
            stack = shipit_repositories(:shipit).stacks.last
            assert_equal stack.environment, "pr2"
            assert_equal stack.continuous_deployment, false
            assert_equal stack.ignore_ci, false
            assert_equal stack.branch, payload_parsed(:pull_request_opened)["pull_request"]["head"]["ref"]
            assert_pending_provision(stack)
          end

          test "auto-created stack should have pull request assigned" do
            payload = payload_parsed(:pull_request_opened)

            assert_difference -> { Shipit::PullRequest.count } do
              OpenedHandler.new(payload).process
            end
          end

          test "only provision stacks for repos with auto-provisioning enabled" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              provisioning_enabled: false,
              behavior: :allow_all
            )

            assert_no_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload_parsed(:provision_disabled_pull_request)).process
            end
          end

          test "ignored duplicate deliveries" do
            OpenedHandler.new(payload_parsed(:pull_request_opened)).process
            assert_no_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload_parsed(:pull_request_opened)).process
            end
          end

          test "creates stacks for repos that allow_all" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :allow_all,
              label: "pull-requests-label"
            )

            assert_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload_parsed(:pull_request_opened)).process
            end
          end

          test "creates stacks for repos that allow_with_label when label is present" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :allow_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_opened)
            payload["pull_request"]["labels"] << { "name" => "pull-requests-label" }

            assert_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload).process
            end
          end

          test "does not create stacks for repos that allow_with_label when label is absent" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :allow_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_opened)
            payload["pull_request"]["labels"] = []

            assert_no_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload).process
            end
          end

          test "create stacks for repos what prevent_with_label when label is absent" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :prevent_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_opened)
            payload["pull_request"]["labels"] = []

            assert_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload).process
            end
          end

          test "does not create stacks for repos what prevent_with_label when label is present" do
            repository = shipit_repositories(:shipit)
            configure_provisioning_behavior(
              repository: repository,
              behavior: :prevent_with_label,
              label: "pull-requests-label"
            )
            payload = payload_parsed(:pull_request_opened)
            payload["pull_request"]["labels"] << { "name" => "pull-requests-label" }

            assert_no_difference -> { Shipit::Stack.count } do
              OpenedHandler.new(payload).process
            end
          end

          def configure_provisioning_behavior(repository:, provisioning_enabled: true, behavior: :allow_all, label: nil)
            repository.review_stacks_enabled = provisioning_enabled
            repository.provisioning_behavior = behavior
            repository.provisioning_label_name = label
            repository.save!

            repository
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
                  }
                )
              )
          end
        end
      end
    end
  end
end
