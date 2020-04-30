# frozen_string_literal: true
require 'test_helper'

module Shipit
  class ShipitTest < ActiveSupport::TestCase
    setup do
      Shipit.instance_variables.each(&Shipit.method(:remove_instance_variable))
    end

    test ".github_teams returns an empty array if there's no team" do
      assert_equal([], Shipit.github_teams)
    end

    test ".github_teams returns the teams key as an array of Team" do
      Shipit.github.stubs(:oauth_teams).returns(['shopify/developers'])
      assert_equal(['shopify/developers'], Shipit.github_teams.map(&:handle))
    end
  end
end
