# frozen_string_literal: true
require 'test_helper'

module Shipit
  class ShipitTest < ActiveSupport::TestCase
    setup do
      Shipit.instance_variables.each(&Shipit.method(:remove_instance_variable))
    end

    test ".github uses indifferent access to search through the Github applications" do
      secrets = ActiveSupport::OrderedOptions.new
      secrets.merge!(Rails::Secrets.parse(['test/dummy/config/secrets.yml'], env: Rails.env))
      secrets.merge!(YAML.load_file('test/dummy/config/secrets_double_github_app.yml'))
      secrets.deep_symbolize_keys!
      Shipit.stubs(:secrets).returns(secrets)
      assert_instance_of(Shipit::GitHubApp, Shipit.github(organization: 'OrgOne'))
      assert_instance_of(Shipit::GitHubApp, Shipit.github(organization: :OrgOne))
      assert_instance_of(Shipit::GitHubApp, Shipit.github(organization: 'orgone'))
      assert_instance_of(Shipit::GitHubApp, Shipit.github(organization: :orgone))
      assert_instance_of(Shipit::GitHubApp, Shipit.github(organization: :OrgTwo))
      Shipit.unstub(:secrets)
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
