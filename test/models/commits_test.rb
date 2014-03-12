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

end
