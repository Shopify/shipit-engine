require 'test_helper'

class FetchDeployedRevisionJobTest < ActiveSupport::TestCase
  setup do
    @stack = stacks(:shipit)
    @job = FetchDeployedRevisionJob.new
    @commit = commits(:fifth)
  end

  test 'the job abort if the stack is deploying' do
    Stack.any_instance.expects(:deploying?).returns(true)
    assert_no_difference 'Deploy.count' do
      @job.perform(stack_id: @stack.id)
    end
  end

  test 'the job abort if #fetch_deployed_revision returns nil' do
    Stack.any_instance.expects(:deploying?).returns(false)
    StackCommands.any_instance.expects(:fetch_deployed_revision).returns(nil)
    Stack.any_instance.expects(:update_deployed_revision).never
    @job.perform(stack_id: @stack.id)
  end

  test 'the job call update_deployed_revision if #fetch_deployed_revision returns something' do
    Stack.any_instance.expects(:deploying?).returns(false)
    StackCommands.any_instance.expects(:fetch_deployed_revision).returns(@commit.sha)
    Stack.any_instance.expects(:update_deployed_revision).with(@commit.sha)
    @job.perform(stack_id: @stack.id)
  end

  test 'the job disabled revision fetching if the #fetch_deployed_revision raise a Command::Error' do
    Stack.any_instance.expects(:deploying?).returns(false)
    StackCommands.any_instance.expects(:fetch_deployed_revision).raises(Command::Error.new("Missing arguments"))
    Stack.any_instance.expects(:update_deployed_revision).never

    assert_raises Command::Error do
      @job.perform(stack_id: @stack.id)
    end

    refute @stack.reload.supports_fetch_deployed_revision?
  end

end
