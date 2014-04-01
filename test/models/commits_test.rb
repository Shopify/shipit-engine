require 'test_helper'

class CommitsTest < ActiveSupport::TestCase

  setup do
    @stack = stacks(:shipit)
    @pr = @stack.commits.new(message: "Merge pull request #31 from Shopify/improve-polling\n\nSeveral improvements to polling")
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

  test "updating to detached broadcasts a 'remove' event" do
    assert_event('remove')
    @commit.update(detached: true)
  end

  test "#destroy broadcasts a 'remove' event" do
    assert_event('remove')
    @commit.destroy
  end

  test "updating broadcasts an 'update' event" do
    assert_event('update')
    @commit.update_attributes(message: "toto")
  end

  test "creating broadcasts a 'create' event" do
    assert_event('create')
    walrus = users(:walrus)
    @stack.commits.create(author: walrus,
                          committer: walrus,
                          sha: "ab12",
                          authored_at: DateTime.now,
                          committed_at: DateTime.now,
                          message: "more fish!")
  end

  private
  def assert_event(type)
    Pubsubstub::RedisPubSub.expects(:publish).with do |channel, event|
      data = JSON.load(event.data)
      event.name == "commit.#{type}" && channel == "stack.#{@stack.id}" && data['url'].match(/#{@stack.to_param}\/commits\/\d+/)
    end
  end
end
