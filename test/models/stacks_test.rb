require 'test_helper'

class StacksTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @expected_base_path = File.join(Rails.root, "shared", "stacks", @stack.repo_owner, @stack.repo_name, @stack.environment)
  end

  test "remote_repo_http_url" do
    assert_equal "https://github.com/#{@stack.repo_owner}/#{@stack.repo_name}", @stack.remote_repo_http_url
  end

  test "remote_repo_git_url" do
    assert_equal "git@github.com:#{@stack.repo_owner}/#{@stack.repo_name}.git", @stack.remote_repo_git_url
  end

  test "local_base_path" do
    assert_equal @expected_base_path, @stack.local_base_path
  end

  test "local_deploys_path" do
    assert_equal File.join(@expected_base_path, "deploys"), @stack.local_deploys_path
  end

  test "local_git_path" do
    assert_equal File.join(@expected_base_path, "git"), @stack.local_git_path
  end
end
