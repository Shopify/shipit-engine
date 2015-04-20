require 'test_helper'

class MembershipTest < ActiveSupport::TestCase
  setup do
    @membership = memberships(:walrus_shopify_developers)
  end

  test "no duplicates are accepted" do
    membership = Membership.new(user: @membership.user, team: @membership.team)
    refute membership.valid?
  end
end
