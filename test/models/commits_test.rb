require 'test_helper'

class CommitsTest < ActiveSupport::TestCase
  setup do
    @stack = stacks(:shipit)
    @pr = @stack.commits.new
    @pr.message = "Merge pull request #31 from Shopify/improve-polling\n\nSeveral improvements to polling"
    @commit = commits(:first)
  end

  test "#pull_request? detect pull request based on message format" do
    assert @pr.pull_request?
    refute @commit.pull_request?
  end

  test "#pull_request_id extract the pull request id from the message" do
    assert_equal 31, @pr.pull_request_id
    assert_nil @commit.pull_request_id
  end

  test "#pull_request_title extract the pull request title from the message" do
    assert_equal 'Several improvements to polling', @pr.pull_request_title
    assert_nil @commit.pull_request_title
  end

  test "#pull_request_url build the pull request url from the message" do
    assert_equal 'https://github.com/shopify/shipit2/pull/31', @pr.pull_request_url
    assert_nil @commit.pull_request_url
  end

  test "#newer_than(nil) returns all commits" do
    assert_equal @stack.commits.all.to_a, @stack.commits.newer_than(nil).to_a
  end

  test "updating to detached broadcasts an update event" do
    expect_event(@stack)
    @commit.update(detached: true)
  end

  test "#destroy broadcasts an update event" do
    expect_event(@stack)
    @commit.destroy
  end

  test "updating broadcasts an update event" do
    expect_event(@stack)
    @commit.update_attributes(message: "toto")
  end

  test "updating state to success triggers new deploy when stack has continuous deployment" do
    @stack.reload.update(continuous_deployment: true)
    @stack.deploys.destroy_all

    assert_difference "Deploy.count" do
      @commit.statuses.create!(state: 'success', context: 'ci/travis')
    end
  end

  test "updating state to success skips deploy when stack has CD but a deploy is in progress" do
    @stack.reload.update(continuous_deployment: true)
    @stack.trigger_deploy(@commit, @commit.committer)

    assert_no_difference "Deploy.count" do
      @commit.statuses.create!(state: 'success', context: 'ci/travis')
    end
  end

  test "updating state to success skips deploy when stack has CD but the stack is locked" do
    @stack.deploys.destroy_all
    @stack.reload.update!(continuous_deployment: true, lock_reason: "Maintenance ongoing")

    assert_no_difference "Deploy.count" do
      @commit.statuses.create!(state: 'success', context: 'ci/travis')
    end
  end

  test "updating won't trigger a deploy if a newer commit has been deployed" do
    @stack.reload.update(continuous_deployment: true)
    @stack.deploys.destroy_all

    walrus = users(:walrus)
    new_commit = @stack.commits.create!(
      sha: '1234',
      message: 'bla',
      author: walrus,
      committer: walrus,
      authored_at: Time.now,
      committed_at: Time.now,
    )

    @stack.deploys.create!(
      user_id: walrus.id,
      since_commit: @stack.last_deployed_commit,
      until_commit: new_commit,
      status: 'success',
    )

    assert_no_difference "Deploy.count" do
      @commit.statuses.create!(state: 'success')
    end
  end

  test "updating without CD skips deploy regardless of state" do
    @stack.reload.deploys.destroy_all

    assert_no_difference "Deploy.count" do
      @commit.statuses.create!(state: 'success')
    end
  end

  test "updating when not success does not schedule CD" do
    @stack.reload.update(continuous_deployment: true)
    @stack.deploys.destroy_all

    assert_no_difference "Deploy.count" do
      @commit.statuses.create!(state: 'failure')
    end
  end

  test "creating broadcasts an update event" do
    expect_event(@stack)
    walrus = users(:walrus)
    @stack.commits.create(author: walrus,
                          committer: walrus,
                          sha: "ab12",
                          authored_at: DateTime.now,
                          committed_at: DateTime.now,
                          message: "more fish!")
  end

  test "refresh_statuses! pull state from github" do
    rels = {target: mock(href: 'http://example.com')}
    status = mock(state: 'success', description: nil, context: 'default', rels: rels, created_at: 1.day.ago)
    Shipit.github_api.expects(:statuses).with(@stack.github_repo_name, @commit.sha).returns([status])
    assert_difference '@commit.statuses.count', +1 do
      @commit.refresh_statuses!
    end
    assert_equal 'success', @commit.statuses.first.state
  end

  test "#creating a commit update the undeployed_commits_count" do
    walrus = users(:walrus)
    assert_equal 3, @stack.undeployed_commits_count
    @stack.commits.create(author: walrus,
                          committer: walrus,
                          sha: "ab12",
                          authored_at: DateTime.now,
                          committed_at: DateTime.now,
                          message: "more fish!")

    @stack.reload
    assert_equal 4, @stack.undeployed_commits_count
  end

  test "fetch_stats! pulls additions and deletions from github" do
    commit = stub(stats: stub(additions: 4242, deletions: 2424))
    Shipit.github_api.expects(:commit).with(@stack.github_repo_name, @commit.sha).returns(commit)
    @commit.fetch_stats!
    assert_equal 4242, @commit.additions
    assert_equal 2424, @commit.deletions
  end

  test "fetch_stats! doesn't fail if the commits have no stats" do
    commit = stub(stats: nil)
    Shipit.github_api.expects(:commit).with(@stack.github_repo_name, @commit.sha).returns(commit)
    assert_nothing_raised do
      @commit.fetch_stats!
    end
  end

  test ".by_sha! can match sha prefixes" do
    assert_equal @commit, Commit.by_sha!(@commit.sha[0..7])
  end

  test ".by_sha! raises on ambigous sha prefixes" do
    assert_raises Commit::AmbiguousRevision do
      Commit.by_sha!(@commit.sha[0..3])
    end
  end

  test ".by_sha! raises if the sha prefix matches multiple commits" do
    clone = Commit.new(@commit.attributes.except('id'))
    clone.sha[8..-1] = 'abc12'
    clone.save!

    assert_raises Commit::AmbiguousRevision do
      Commit.by_sha!(@commit.sha[0..7])
    end
  end

  test "#state is `unknown` by default" do
    assert_equal 'unknown', Commit.new.state
  end

  test "#state is `success` if all most recent the statuses are `success`" do
    assert_equal 'success', commits(:third).state
  end

  test "#state is `failure` one of the most recent the statuses is `failure`" do
    assert_equal 'failure', commits(:second).state
  end

  test "#state is `pending` one of the most recent the statuses is `pending` and none is `failure` or `error`" do
    assert_equal 'pending', commits(:fourth).state
  end

  private

  def expect_event(stack)
    Pubsubstub::RedisPubSub.expects(:publish).at_least_once
    Pubsubstub::RedisPubSub.expects(:publish).with do |channel, event|
      data = JSON.load(event.data)
      channel == "stack.#{stack.id}" && data['url'] == "/#{stack.to_param}"
    end
  end
end
