# frozen_string_literal: true
require 'test_helper'

module Shipit
  class PullRequestAssignmentTest < ActiveSupport::TestCase
    setup do
      @assignment = shipit_pull_request_assignments(:walrus_shopify_developers)
    end

    test "no duplicates are accepted" do
      assignment = PullRequestAssignment.new(user: @assignment.user, merge_request: @assignment.merge_request)
      refute assignment.valid?
    end
  end
end
