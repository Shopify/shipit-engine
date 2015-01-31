require 'test_helper'

class StatusTest < ActiveSupport::TestCase
  setup do
    @commit = commits(:first)
    @stack = @commit.stack
  end

  test ".replicate_from_github! is idempotent" do
    status = OpenStruct.new(
      state: 'success',
      description: 'This is a description',
      context: 'default',
      target_url: 'http://example.com',
      created_at: 1.day.ago.to_time,
    )

    assert_difference '@commit.statuses.count', +1 do
      @commit.statuses.replicate_from_github!(status)
    end

    assert_no_difference '@commit.statuses.count' do
      @commit.statuses.replicate_from_github!(status)
    end
  end

  test "once created a commit broadcasts an update event" do
    expect_event(@stack)
    @commit.statuses.create!(state: 'success')
  end

  private

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
