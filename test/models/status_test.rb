require 'test_helper'

class StatusTest < ActiveSupport::TestCase
  setup do
    @commit = commits(:first)
    @stack = @commit.stack
  end

  test ".replicate_from_github! is idempotent" do
    status = OpenStruct.new(state: 'success', description: 'This is a description', context: 'default', target_url: 'http://example.com', created_at: 1.day.ago)

    assert_difference '@commit.statuses.count', +1 do
      @commit.statuses.replicate_from_github!(status)
    end

    assert_no_difference '@commit.statuses.count' do
      @commit.statuses.replicate_from_github!(status)
    end
  end
end
