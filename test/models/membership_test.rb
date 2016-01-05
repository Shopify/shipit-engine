require 'test_helper'

module Shipit
  class MembershipTest < ActiveSupport::TestCase
    setup do
      @membership = shipit_memberships(:walrus_shopify_developers)
    end

    test "no duplicates are accepted" do
      membership = Membership.new(user: @membership.user, team: @membership.team)
      refute membership.valid?
    end
  end
end
