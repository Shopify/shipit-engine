require 'test_helper'

class NotifyStackUsersJobTest < ActiveSupport::TestCase
  setup do
    @job = NotifyStackUsersJob.new
    @stack = stacks(:shipit)
    @commit = commits(:first)
  end

  test "#perform calls notify when there are old undeployed commits" do
    @job.expects(:notify).once
    assert_equal @stack.old_undeployed_commits.class, Commit::ActiveRecord_Relation
    @job.perform(stack_id: @stack.id)
  end

  test "#perform does not notify users when the stack doesn't have old undeployed commits" do
    @job.expects(:notify).never
    Stack.any_instance.expects(:old_undeployed_commits).returns(nil)
    @job.perform(stack_id: @stack.id)
  end

  test "#escaped_json outputs parsable json" do
    escaped_json = @job.escaped_json(@stack, @commit.committer_id)
    assert JSON.parse(URI.unescape(escaped_json))
  end

  test "#escaped_json outputs json that contains the stack's name, branch and committer's name" do
    escaped_json = @job.escaped_json(@stack, @commit.committer_id)
    json = JSON.parse(URI.unescape(escaped_json))
    expected_values = [@stack.repo_name, @stack.branch, @commit.committer]
    actual_values = [json["repo_name"], json["repo_branch"], User.find_by_name(json["authors"].first["name"])]
    assert_equal expected_values, actual_values
  end
end
