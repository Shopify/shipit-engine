require 'test_helper'

class StatusTest < ActiveSupport::TestCase
  setup do
    @commit = commits(:first)
    @stack = @commit.stack
  end

  test ".replicate_from_github! is idempotent" do
    assert_difference '@commit.statuses.count', +1 do
      @commit.statuses.replicate_from_github!(github_status)
    end

    assert_no_difference '@commit.statuses.count' do
      @commit.statuses.replicate_from_github!(github_status)
    end
  end

  test "once created a commit broadcasts an update event" do
    expect_event(@stack)
    @commit.statuses.create!(state: 'success')
  end

  test ".replicate_from_github! touches the related stack" do
    stack_last_updated_at = @stack.updated_at
    commit_last_updated_at = @commit.updated_at

    @commit.statuses.replicate_from_github!(github_status)

    assert_not_equal commit_last_updated_at, @commit.reload.updated_at
    assert_not_equal stack_last_updated_at, @stack.reload.updated_at
  end

  private

  def github_status
    OpenStruct.new(
      state: 'success',
      description: 'This is a description',
      context: 'default',
      target_url: 'http://example.com',
      created_at: 1.day.ago.to_time,
    )
  end

  def expect_event(stack)
    Pubsubstub::RedisPubSub.expects(:publish).at_least_once
    Pubsubstub::RedisPubSub.expects(:publish).with do |channel, event|
      data = JSON.load(event.data)
      event.name == 'stack.update' &&
        channel == "stack.#{stack.id}" &&
        data['url'] == "/#{stack.to_param}"
    end
  end
end
