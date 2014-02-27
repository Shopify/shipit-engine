require 'test_helper'

class GithubUrlHelperTest < ActiveSupport::TestCase
  include GithubUrlHelper

  test "#github_url returns the base github url" do
    assert_equal "https://github.com", github_url
  end

  test "#github_repo_url returns a repo url" do
    assert_equal "https://github.com/rails/rails", github_repo_url("rails", "rails").to_s
  end

  test "#github_commit_url returns a commit url" do
    sha      = SecureRandom.hex
    expected = "https://github.com/rails/rails/commit/#{sha}"

    assert_equal expected, github_commit_url("rails", "rails", sha).to_s
  end

  test "#github_diff_url returns a diff url" do
    from_sha = SecureRandom.hex
    to_sha   = SecureRandom.hex
    expected = "https://github.com/rails/rails/compare/#{from_sha}...#{to_sha}"

    assert_equal expected, github_diff_url("rails", "rails", from_sha, to_sha).to_s
  end
end
