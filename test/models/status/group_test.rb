require 'test_helper'

module Shipit
  class StatusGroupTest < ActiveSupport::TestCase
    setup do
      @commit = shipit_commits(:second)
      @group = Status::Group.new(@commit, @commit.statuses)
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
      assert_equal %w(success failure), @group.statuses.map(&:state)
      assert_equal 'failure', @group.state
    end

    test "#blocking? returns true if any of the status is blocking" do
      blocking_status = shipit_statuses(:soc_first)
      assert_predicate blocking_status, :blocking?
      Status::Group.new(blocking_status.commit, [blocking_status])
    end

    test ".compact returns a regular status if there is only one visible status" do
      status = Status::Group.compact(@commit, @commit.statuses.where(context: 'ci/travis'))
      assert_instance_of Status, status
    end

    test ".compact returns an unknown status if there is no visible status" do
      status = Status::Group.compact(@commit, @commit.statuses.where(context: 'ci/none'))
      assert_instance_of Status::Unknown, status
    end

    test "missing required status will have MissingRequiredStatus as placeholder" do
      @commit.stubs(:required_statuses).returns(%w(ci/very-important))
      status = Status::Group.compact(@commit, [])
      assert_instance_of Status::Missing, status
      assert_predicate status, :pending?
    end
  end
end
