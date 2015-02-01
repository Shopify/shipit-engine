require 'test_helper'

class UndeployedCommitsWebhookJobTest < ActiveSupport::TestCase
  setup do
    @job = UndeployedCommitsWebhookJob
    @stack = stacks(:shipit)
    @commit = commits(:first)
  end

  test "#perform calls #send_reminder when there are old undeployed commits and no deploy" do
    Stack.any_instance.expects(:old_undeployed_commits).returns(@stack.commits)
    Stack.any_instance.expects(:deploying?).returns(false)
    @job.any_instance.expects(:send_reminder).once
    @job.perform(stack_id: @stack.id)
  end

  test "#perform does not call #send_reminder when the stack doesn't have old undeployed commits" do
    Stack.any_instance.expects(:old_undeployed_commits).returns([])
    Stack.any_instance.expects(:deploying?).returns(false)
    @job.any_instance.expects(:send_reminder).never
    @job.perform(stack_id: @stack.id)
  end

  test "#perform does not call #send_reminder when the stack is locked" do
    Stack.any_instance.expects(:locked?).returns(true)
    Stack.any_instance.stubs(:old_undeployed_commits).returns(@stack.commits)
    @job.any_instance.expects(:send_reminder).never
    @job.perform(stack_id: @stack.id)
  end

  test "#perform does not call #send_reminder when the stack is deploying" do
    Stack.any_instance.expects(:deploying?).returns(true)
    Stack.any_instance.stubs(:old_undeployed_commits).returns(@stack.commits)
    @job.any_instance.expects(:send_reminder).never
    @job.perform(stack_id: @stack.id)
  end

  test "#build_stack_committer_json outputs parsable json" do
    stack_committer_info = @job.new(stack_id: @stack.id).build_stack_committer_json([@commit.committer_id])
    assert JSON.parse(stack_committer_info)
  end

  test "#build_stack_committer_json outputs json that contains the stack's name, branch and committer's name" do
    stack_committer_info = @job.new(stack_id: @stack.id).build_stack_committer_json([@commit.committer_id])
    json = JSON.parse(stack_committer_info)
    expected_values = [@stack.repo_name, @stack.branch, @commit.committer]
    actual_values = [json["repo_name"], json["repo_branch"], User.find_by_name(json["authors"].first["name"])]
    assert_equal expected_values, actual_values
  end

  test "#send_reminder posts the stack_committer_json to reminder_url with Faraday" do
    @stack.update_attributes(reminder_url: "http://www.example.com")
    Stack.any_instance.expects(:old_undeployed_commits).returns(@stack.commits)
    Stack.any_instance.expects(:deploying?).returns(false)
    job = @job.new(stack_id: @stack.id)
    stack_committer_json = job.build_stack_committer_json(@stack.commits.pluck(:committer_id).uniq)
    Faraday.expects(:post).with(@stack.reminder_url, 'stack_committer_json' => stack_committer_json).once
    @job.perform(stack_id: @stack.id)
  end
end
