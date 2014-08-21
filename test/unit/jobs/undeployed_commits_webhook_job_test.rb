require 'test_helper'

class UndeployedCommitsWebhookJobTest < ActiveSupport::TestCase
  setup do
    @job = UndeployedCommitsWebhookJob.new
    @stack = stacks(:shipit)
    @commit = commits(:first)
  end

  test "#perform calls send_reminder when there are old undeployed commits" do
    Stack.any_instance.expects(:old_undeployed_commits).returns(@stack.commits)
    @job.expects(:send_reminder).once
    @job.perform(stack_id: @stack.id)
  end

  test "#perform does not send_reminder users when the stack doesn't have old undeployed commits" do
    Stack.any_instance.expects(:old_undeployed_commits).returns([])
    @job.expects(:send_reminder).never
    @job.perform(stack_id: @stack.id)
  end

  test "#build_stack_committer_json outputs parsable json" do
    stack_committer_info = @job.build_stack_committer_json(@stack, [@commit.committer_id])
    assert JSON.parse(stack_committer_info)
  end

  test "#build_stack_committer_json outputs json that contains the stack's name, branch and committer's name" do
    stack_committer_info = @job.build_stack_committer_json(@stack, [@commit.committer_id])
    json = JSON.parse(stack_committer_info)
    expected_values = [@stack.repo_name, @stack.branch, @commit.committer]
    actual_values = [json["repo_name"], json["repo_branch"], User.find_by_name(json["authors"].first["name"])]
    assert_equal expected_values, actual_values
  end

  test "#send_reminder posts the stack_committer_json to reminder_url with Faraday" do
    @stack.update_attributes(reminder_url: "http://www.example.com")
    expected_hash = { "stack_committer_json" => @job.build_stack_committer_json(@stack, @stack.commits.pluck(:committer_id).uniq) }
    Stack.any_instance.expects(:old_undeployed_commits).returns(@stack.commits)
    Faraday.expects(:post).with(@stack.reminder_url, expected_hash).once
    @job.perform(stack_id: @stack.id)
  end
end
