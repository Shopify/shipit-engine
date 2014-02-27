require 'test_helper'

class StackCommandsTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @commands = StackCommands.new(@stack)
    stub_git_calls
  end

  test "something" do
    # ...
  end

  private

  def stub_git_calls
    StackCommands.any_instance.stubs(:git).returns(true)
  end
end
