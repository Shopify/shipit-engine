# frozen_string_literal: true

require "test_helper"

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class EditedHandlerTest < ActiveSupport::TestCase
          test "validates payload" do
            assert_raise(StandardError) { EditedHandler.new(payload_parsed(:invalid_pull_request)) }
          end

          test "updates the existing PullRequest" do
            pull_request = shipit_pull_requests(:review_stack_review)
            payload = payload_parsed(:pull_request_opened)
            payload["action"] = "edited"
            payload["number"] = pull_request.number
            payload["pull_request"]["title"] = "New Title"

            assert_changes -> { pull_request.reload.title }, to: "New Title" do
              EditedHandler.new(payload).process
            end
          end

          test "does not attempt to update when PullRequest does not exist" do
            unknown_pull_request_number = 999
            payload = payload_parsed(:pull_request_opened)
            payload["number"] = unknown_pull_request_number
            payload["action"] = "edited"
            payload["pull_request"]["title"] = "New Title"

            assert_no_enqueued_jobs do
              EditedHandler.new(payload).process
            end
          end

          test "ignores non pull_request 'edited' webhooks" do
            assert_no_difference -> { Shipit::Stack.not_archived.count } do
              EditedHandler.new(payload_parsed(:pull_request_opened).merge(action: "assigned")).process
            end
          end
        end
      end
    end
  end
end
