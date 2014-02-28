require 'test_helper'

class DeploysTest < ActiveSupport::TestCase
  def setup
    @deploy = deploys(:shipit)
  end

  test "working_directory" do
    assert_equal File.join(@deploy.stack.deploys_path, @deploy.id.to_s), @deploy.working_directory
  end

  test "#since_commit_id returns the database value if present" do
    @deploy.expects(:read_attribute).with(:since_commit_id).returns(1)
    assert_equal 1, @deploy.since_commit_id
  end

  test "#since_commit_id returns nil if stack_id isn't set" do
    deploy = Deploy.new
    assert_nil deploy.since_commit_id
  end

  test "#since_commit_id returns a default value if stack_id is set" do
    stack  = stacks(:shipit)
    deploy = stack.deploys.new
    last   = stack.deploys.where(:status => "success").last.until_commit_id
    assert_equal last, deploy.since_commit_id
  end

  test "#commits returns empty array if stack isn't set" do
    @deploy.expects(:stack).returns(nil)
    assert_equal [], @deploy.commits
  end

  test "#commits returns the commits in the id range" do
    stack = stacks(:shipit)
    first = commits(:first)
    last  = commits(:third)

    deploy = stack.deploys.new(
      :since_commit => first,
      :until_commit => last
    )

    commits = deploy.commits

    assert_not_empty commits
    assert_equal last.id, commits.map(&:id).max
    assert_not_equal first.id, commits.map(&:id).min
  end
end
