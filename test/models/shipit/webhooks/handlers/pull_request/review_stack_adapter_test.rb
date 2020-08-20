# frozen_string_literal: true

require "test_helper"

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class ReviewStackAdapterTest < ActiveSupport::TestCase
          test "unarchive! on an unarchived stack is a no-op" do
            stack = create_stack
            review_stack = Shipit::Webhooks::Handlers::PullRequest::ReviewStackAdapter.new(
              params_for(stack),
              scope: stack.repository.stacks
            )
            Shipit::ReviewStack.any_instance.expects(:unarchive!).never
            Shipit::ReviewStackProvisioningQueue.expects(:add).never

            review_stack.unarchive!
          end

          test "archive! on an archived stack is a no-op" do
            stack = create_archived_stack
            review_stack = Shipit::Webhooks::Handlers::PullRequest::ReviewStackAdapter.new(
              params_for(stack),
              scope: stack.repository.stacks
            )
            Shipit::Stack.any_instance.expects(:archive!).never

            review_stack.archive!
          end

          def params_for(stack)
            OpenStruct.new(
              number: pr_number,
              repository: {
                "full_name" => stack.github_repo_name,
              }
            )
          end

          def create_stack
            stack = shipit_stacks(:shipit)
            stack.environment = environment

            stack.save!

            stack
          end

          def create_archived_stack
            stack = create_stack
            stack.archive!(shipit_users(:walrus))

            stack
          end

          def pr_number
            1
          end

          def environment
            "pr#{pr_number}"
          end
        end
      end
    end
  end
end
