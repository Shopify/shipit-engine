# frozen_string_literal: true
require 'test_helper'

module Shipit
  class MergeRequestAssignmentTest < ActiveSupport::TestCase
    setup do
      @assignment = shipit_merge_request_assignments(:walrus_shopify_developers)
    end

    test "no duplicates are accepted" do
      assignment = MergeRequestAssignment.new(user: @assignment.user, merge_request: @assignment.merge_request)
      refute assignment.valid?
    end
  end
end
