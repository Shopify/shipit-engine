# frozen_string_literal: true

require 'test_helper'

module Shipit
  class GithubUrlHelperTest < ActiveSupport::TestCase
    include Shipit::GithubUrlHelper

    test "#github_user_url returns a user url" do
      assert_equal "https://github.com/tobi", github_user_url("tobi")
    end

    test "#github_repo_url returns a repo url" do
      assert_equal "https://github.com/rails/rails", github_repo_url("rails", "rails")
    end

    test "#github_commit_url returns a commit url" do
      expected = 'https://github.com/shopify/shipit-engine/commit/6d9278037b872fd9a6690523e411ecb3aa181355'
      assert_equal expected, github_commit_url(shipit_commits(:first))
    end

    test "#github_pull_request_url returns a PR url" do
      expected = 'https://github.com/shopify/shipit-engine/pull/62'
      assert_equal expected, github_pull_request_url(shipit_merge_requests(:shipit_pending))
    end
  end
end
