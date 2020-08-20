# frozen_string_literal: true

require "test_helper"

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class AssignedHandlerTest < ActiveSupport::TestCase
          test "validates payload" do
            assert_raise(StandardError) { AssignedHandler.new(payload_parsed(:invalid_pull_request)) }
          end

          test "ignores irrelevant PR actions" do
            assert_no_enqueued_jobs do
              AssignedHandler.new(payload_parsed(:pull_request_assigned).merge(action: "labeled")).process
            end
          end

          test "updates the existing PullRequest's assignees" do
            pull_request = shipit_pull_requests(:review_stack_review)
            pull_request.assignees.clear
            payload = payload_parsed(:pull_request_assigned)
            payload["number"] = pull_request.number
            payload["pull_request"]["number"] = pull_request.number

            AssignedHandler.new(payload).process

            assert [shipit_users(:codertocat)], pull_request.reload.assignees
          end

          test "does not attempt to update when PullRequest does not exist" do
            unknown_pull_request_number = 999
            payload = payload_parsed(:pull_request_assigned)
            payload["number"] = unknown_pull_request_number

            assert_no_changes -> { Shipit::PullRequestAssignment.count } do
              AssignedHandler.new(payload).process
            end
          end
        end
      end
    end
  end
end
