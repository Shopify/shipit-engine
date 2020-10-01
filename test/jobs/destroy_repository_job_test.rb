# frozen_string_literal: true
require 'test_helper'

module Shipit
  class DestroyRepositoryJobTest < ActiveSupport::TestCase
    setup do
      @job = DestroyRepositoryJob.new
      @repository = Repository.first
    end

    test "perform destroys the repository" do
      assert_difference -> { Repository.count }, -1 do
        @job.perform(@repository)
      end
    end

    test "perform destroys the repository's stacks" do
      stack = Stack.first
      Shipit.github.api.expects(:remove_hook).times(stack.github_hooks.count)
      @repository.stacks << stack

      assert_difference -> { Stack.count }, -@repository.stacks.size do
        @job.perform(@repository)
      end
    end
  end
end
