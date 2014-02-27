require 'test_helper'

class StacksTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @expected_base_path = File.join(Rails.root, "shared", "stacks", @stack.repo_owner, @stack.repo_name, @stack.environment)
  end

  test "repo_http_url" do
    assert_equal "https://github.com/#{@stack.repo_owner}/#{@stack.repo_name}", @stack.repo_http_url
  end

  test "repo_git_url" do
    assert_equal "git@github.com:#{@stack.repo_owner}/#{@stack.repo_name}.git", @stack.repo_git_url
  end

  test "base_path" do
    assert_equal @expected_base_path, @stack.base_path
  end

  test "deploys_path" do
    assert_equal File.join(@expected_base_path, "deploys"), @stack.deploys_path
  end

  test "git_path" do
    assert_equal File.join(@expected_base_path, "git"), @stack.git_path
  end
end
