require 'test_helper'

module Shipit
  class DestroyStackJobTest < ActiveSupport::TestCase
    setup do
      @job = DestroyStackJob.new
      @stack = Stack.first
    end

    test "perform destroys the received stack" do
      Shipit.github.api.expects(:remove_hook).times(@stack.github_hooks.count)

      assert_difference -> { Stack.count }, -1 do
        @job.perform(@stack)
      end
    end
  end
end
