require 'test_helper'

class StatusTest < ActiveSupport::TestCase

  setup do
    @commit = commits(:first)
  end

  test "commit's state has changed after new status received" do

     @commit.statuses.create!(:state => "failure")
     assert_equal "failure", @commit.state
   end

  test "commit only updates state for status with newest 'created_at' received" do
    @commit.statuses.create!(:state => "failure", :created_at => 12.days.ago.to_s(:db))
    assert_equal "pending", @commit.state
  end
end
