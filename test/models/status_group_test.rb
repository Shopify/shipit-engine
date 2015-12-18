require 'test_helper'

class StatusGroupTest < ActiveSupport::TestCase
  setup do
    @commit = commits(:second)
    @group = StatusGroup.new(@commit.significant_status, @commit.visible_statuses)
  end

  test "#description is a summary of the statuses" do
    assert_equal '1 / 2 checks OK', @group.description
  end

  test "#group? returns true" do
    assert_equal true, @group.group?
  end

  test "#target_url returns nil" do
    assert_nil @group.target_url
  end

  test "#state is significant's status state" do
    assert_equal @commit.significant_status.state, @group.state
  end
end
