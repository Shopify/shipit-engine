require 'test_helper'

class GithubUrlHelperTest < ActiveSupport::TestCase
  include GithubUrlHelper

  test "#github_url returns the base github url" do
    assert_equal "https://github.com", github_url
  end

  test "#github_user_url returns a user url" do
    assert_equal "https://github.com/tobi", github_user_url("tobi")
  end

  test "#github_repo_url returns a repo url" do
    assert_equal "https://github.com/rails/rails", github_repo_url("rails", "rails")
  end

  test "#github_commit_url returns a commit url" do
    expected = 'https://github.com/shopify/shopify/commit/6d9278037b872fd9a6690523e411ecb3aa181355'
    assert_equal expected, github_commit_url(commits(:first))
  end

  test "#github_diff_url returns a diff url" do
    from_sha = SecureRandom.hex
    to_sha   = SecureRandom.hex
    expected = "https://github.com/rails/rails/compare/#{from_sha}...#{to_sha}"

    assert_equal expected, github_diff_url("rails", "rails", from_sha, to_sha)
  end
end
