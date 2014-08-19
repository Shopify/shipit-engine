require 'test_helper'

class UndeployedCommitsWebhookJobTest < ActiveSupport::TestCase
  setup do
    @job = UndeployedCommitsWebhookJob.new
    @stack = stacks(:shipit)
    @commit = commits(:first)
  end

  test "#perform calls send_reminder when there are old undeployed commits" do
    @job.expects(:send_reminder).once
    assert_equal @stack.old_undeployed_commits.class, Commit::ActiveRecord_Relation
    @job.perform(stack_id: @stack.id)
  end

  test "#perform does not send_reminder users when the stack doesn't have old undeployed commits" do
    @job.expects(:send_reminder).never
    Stack.any_instance.expects(:old_undeployed_commits).returns(nil)
    @job.perform(stack_id: @stack.id)
  end

  test "#build_stack_committer_info outputs parsable json" do
    stack_committer_info = @job.build_stack_committer_info(@stack, @commit.committer_id)
    assert JSON.parse(stack_committer_info)
  end

  test "#build_stack_committer_info outputs json that contains the stack's name, branch and committer's name" do
    stack_committer_info = @job.build_stack_committer_info(@stack, @commit.committer_id)
    json = JSON.parse(stack_committer_info)
    expected_values = [@stack.repo_name, @stack.branch, @commit.committer]
    actual_values = [json["repo_name"], json["repo_branch"], User.find_by_name(json["authors"].first["name"])]
    assert_equal expected_values, actual_values
  end
end
