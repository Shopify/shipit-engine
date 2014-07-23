require 'test_helper'

class ShipitReminderJobTest < ActiveSupport::TestCase
  setup do
    @job = ShipitReminderJob.new
    @stack = stacks(:shipit)
  end

  test "#perform enqueues a NotifyStackUsersJob for stacks that require reminder" do
    @stack.update_attributes(reminder_url: 'http://www.example.com')
    Resque.expects(:enqueue).with(NotifyStackUsersJob, stack_id: @stack.id).once
    @job.perform
  end

  test "#perform does nothing for stacks that haven't set their reminder_url" do
    @stack.update_attributes( reminder_url: nil)
    Resque.expects(:enqueue).with(NotifyStackUsersJob, stack_id: @stack.id).never
    @job.perform
  end

  test "#perform does nothing for stacks reminder_url is an empty string" do
    @stack.update_attributes( reminder_url: '')
    Resque.expects(:enqueue).with(NotifyStackUsersJob, stack_id: @stack.id).never
    @job.perform
  end
end
