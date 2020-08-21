# frozen_string_literal: true

require "test_helper"

module Shipit
  class PulLRequestSerializerTest < ActiveSupport::TestCase
    test "structure" do
      pull_request = shipit_pull_requests(:review_stack_review)

      serialized = serializer.new(pull_request).as_json

      assert_includes serialized.keys, :id
      assert_includes serialized.keys, :number
      assert_includes serialized.keys, :title
      assert_includes serialized.keys, :github_id
      assert_includes serialized.keys, :additions
      assert_includes serialized.keys, :deletions
      assert_includes serialized.keys, :state
      assert_includes serialized.keys, :html_url
      assert_includes serialized.keys, :user
      assert_includes serialized.keys, :assignees
    end

    def serializer
      Shipit::PullRequestSerializer
    end
  end
end
