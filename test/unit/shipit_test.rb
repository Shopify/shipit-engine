# frozen_string_literal: true

require 'test_helper'

module Shipit
  class ShipitTest < ActiveSupport::TestCase
    setup do
      Shipit.instance_variables.each(&Shipit.method(:remove_instance_variable))
    end

    test ".github uses indifferent access to search through the Github applications" do
      secrets = ActiveSupport::OrderedOptions.new
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

    class RedisTest < self
      setup do
        @client = mock(:client)
      end

      teardown do
        Shipit.instance_variables.each(&Shipit.method(:remove_instance_variable))
        Redis.unstub(:new)
      end

      test ".redis should build a new redis client" do
        Redis.expects(:new).with(
          has_entries(
            url: Shipit.redis_url.to_s,
            reconnect_attempts: 3,
            reconnect_delay: 0.5,
            reconnect_delay_max: 1
          )
        ).returns(@client)

        assert_equal(@client, Shipit.redis)
      end

      test ".redis should return an existing redis client" do
        Redis.expects(:new).once.returns(@client)

        2.times do
          assert_equal(@client, Shipit.redis)
        end
      end

      test ".redis= should set the redis client" do
        Shipit.redis = @client

        assert_equal(@client, Shipit.redis)
      end

      test ".redis= should set and memoize the redis client" do
        Shipit.redis = @client

        Redis.expects(:new).never

        assert_equal(@client, Shipit.redis)
      end
    end
  end
end
