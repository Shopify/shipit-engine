require 'test_helper'

module Shipit
  class UnknownRepositoryTest < ActiveSupport::TestCase
    setup do
      @unknown_repository = UnknownRepository.new
    end

    test "owner" do
      assert_equal "unknown-owner", @unknown_repository.owner
    end

    test "name" do
      assert_equal "unknown-name", @unknown_repository.name
    end

    test "stacks" do
      assert_equal Stack.none, @unknown_repository.stacks
    end

    test "http_url" do
      assert_equal "https://github.com/#{@unknown_repository.owner}/#{@unknown_repository.name}", @unknown_repository.http_url
    end

    test "git_url" do
      assert_equal "https://github.com/#{@unknown_repository.owner}/#{@unknown_repository.name}.git", @unknown_repository.git_url
    end
  end
end
