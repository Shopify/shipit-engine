# frozen_string_literal: true

require "test_helper"

module Shipit
  class DeploySerializerTest < ActiveSupport::TestCase
    setup do
      @deploy = shipit_deploys(:shipit_pending)
      @commits_count = @deploy.commits.count
      assert_operator @commits_count, :>, 1
    end

    test "embeds every commit when serialized without an API context" do
      serialized = serializer.new(@deploy).as_json

      assert_equal @commits_count, serialized[:commits].size
      assert_equal @commits_count, serialized[:commits_count]
      refute serialized[:commits_truncated]
    end

    test "caps embedded commits at the context's commits_limit" do
      serialized = serializer.new(@deploy, context: { commits_limit: 1 }).as_json

      assert_equal 1, serialized[:commits].size
      assert_equal @commits_count, serialized[:commits_count]
      assert serialized[:commits_truncated]
    end

    test "embeds the most recent commits when truncating" do
      serialized = serializer.new(@deploy, context: { commits_limit: 1 }).as_json

      assert_equal @deploy.until_commit.sha, serialized[:commits].first[:sha]
    end

    def serializer
      Shipit::DeploySerializer
    end
  end
end
