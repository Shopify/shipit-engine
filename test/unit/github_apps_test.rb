# frozen_string_literal: true

require 'test_helper'

module Shipit
  class GitHubAppsTestOrgOne < ActiveSupport::TestCase
    setup do
      @organization = "OrgOne"
      @github = app(@organization)
      @enterprise = app(@organization, domain: 'github.example.com')
      @rails_env = Rails.env
      @token_cache_key = "github:integration:#{@organization.downcase}:access-token"
      Rails.cache.delete(@token_cache_key)
    end

    teardown do
      Rails.env = @rails_env
      Rails.cache.delete(@token_cache_key)
    end

    test "#domain defaults to github.com" do
      assert_equal 'github.com', @github.domain
    end

    test "#url returns the HTTPS url to the github installation" do
      assert_equal 'https://github.example.com', @enterprise.url
      assert_equal 'https://github.example.com/foo/bar', @enterprise.url('/foo/bar')
      assert_equal 'https://github.example.com/foo/bar/baz', @enterprise.url('foo/bar', 'baz')
    end

    test "#new_client retruns an Octokit::Client configured to use the github installation" do
      assert_equal 'https://github.example.com/', @enterprise.new_client.web_endpoint
      assert_equal 'https://github.example.com/api/v3/', @enterprise.new_client.api_endpoint
    end

    test "#oauth_config.last[:client_options] is nil if domain is not overriden" do
      assert_nil @github.oauth_config.last[:client_options][:site]
    end

    test "#oauth_config.last[:client_options] returns Enterprise endpoint if domain is overriden" do
      assert_equal 'https://github.example.com/api/v3/', @enterprise.oauth_config.last[:client_options][:site]
    end

    test "#initialize doesn't raise if given an empty config" do
      assert_nothing_raised do
        GitHubApp.new(@organization, {})
      end
    end

    test "#api_status" do
      stub_request(:get, "https://www.githubstatus.com/api/v2/components.json").to_return(
        status: 200,
        body: %(
          {
            "page":{},
            "components":[
              {
                "id":"brv1bkgrwx7q",
                "name":"API Requests",
                "status":"operational",
                "created_at":"2017-01-31T20:01:46.621Z",
                "updated_at":"2019-07-23T18:41:18.197Z",
                "position":2,
                "description":"Requests for GitHub APIs",
                "showcase":false,
                "group_id":null,
                "page_id":"kctbh9vrtdwd",
                "group":false,
                "only_show_if_degraded":false
              }
            ]
          }
        ),
      )
      assert_equal "operational", app(@organization).api_status[:status]
    end

    test "#github token is refreshed after expiration" do
      Rails.env = 'not_test'
      config = {
        app_id: "test_id",
        installation_id: "test_installation_id",
        private_key: "test_private_key",
      }
      initial_token = OpenStruct.new(
        token: "some_initial_github_token",
        expires_at: Time.now.utc + 60.minutes,
      )
      second_token = OpenStruct.new(
        token: "some_new_github_token",
        expires_at: initial_token.expires_at + 60.minutes,
      )
      auth_payload = "test_auth_payload"

      GitHubApp.any_instance.expects(:authentication_payload).twice.returns(auth_payload)
      valid_app = app(@organization, config)

      freeze_time do
        Octokit::Client
          .any_instance
          .expects(:create_app_installation_access_token).twice.with(config[:installation_id], anything)
          .returns(initial_token, second_token)

        initial_token = valid_app.token
        initial_cached_token = Rails.cache.fetch(@token_cache_key)
        assert_equal initial_token, initial_cached_token.to_s

        travel 5.minutes
        assert_equal initial_token, valid_app.token

        travel_to initial_cached_token.expires_at + 5.minutes
        assert_equal second_token.token, valid_app.token
      end
    end

    test "#github token is refreshed in refresh window before expiry" do
      Rails.env = 'not_test'
      config = {
        app_id: "test_id",
        installation_id: "test_installation_id",
        private_key: "test_private_key",
      }
      initial_token = OpenStruct.new(
        token: "some_initial_github_token",
        expires_at: Time.now.utc + 60.minutes,
      )
      second_token = OpenStruct.new(
        token: "some_new_github_token",
        expires_at: initial_token.expires_at + 60.minutes,
      )
      auth_payload = "test_auth_payload"

      GitHubApp.any_instance.expects(:authentication_payload).twice.returns(auth_payload)
      valid_app = app(@organization, config)

      freeze_time do
        Octokit::Client
          .any_instance
          .expects(:create_app_installation_access_token).twice.with(config[:installation_id], anything)
          .returns(initial_token, second_token)

        initial_token = valid_app.token
        initial_cached_token = Rails.cache.fetch(@token_cache_key)
        assert_equal initial_token, initial_cached_token.to_s

        # Travel forward, but before the token is refreshed, so the cached value should be the same.
        travel 40.minutes
        assert_equal initial_token, valid_app.token

        # Travel to when the token should refresh, but is not expired, which should result in our cache.fetch update block.
        travel 15.minutes
        updated_token = valid_app.token
        assert_not_equal initial_token, updated_token

        cached_token = Rails.cache.fetch(@token_cache_key)
        assert_operator cached_token.expires_at, :>, initial_cached_token.expires_at
      end
    end

    test "#github token is missing refresh_at field" do
      # $debugging = true
      Rails.env = 'not_test'
      config = {
        app_id: "test_id",
        installation_id: "test_installation_id",
        private_key: "test_private_key",
      }
      initial_cached_token = Shipit::GitHubApp::Token.new("some_initial_github_token", Time.now.utc - 1.minute)
      initial_cached_token.instance_variable_set(:@refresh_at, nil)

      second_token = OpenStruct.new(
        token: "some_new_github_token",
        expires_at: initial_cached_token.expires_at + 60.minutes,
      )
      auth_payload = "test_auth_payload"

      GitHubApp.any_instance.expects(:authentication_payload).returns(auth_payload)
      valid_app = app(@organization, config)

      freeze_time do
        valid_app.instance_variable_set(:@token, initial_cached_token)
        Rails.cache.write(@token_cache_key, initial_cached_token, expires_in: 1.minute)

        Octokit::Client
          .any_instance
          .expects(:create_app_installation_access_token).with(config[:installation_id], anything)
          .returns(second_token)

        first_token = valid_app.token

        first_cached_token = Rails.cache.fetch(@token_cache_key)
        assert_equal first_token, first_cached_token.to_s

        travel_to first_cached_token.expires_at + 5.minutes
        new_token = valid_app.token

        assert_equal second_token.token, new_token
      end
    end

    private

    def app(organization, extra_config = {})
      GitHubApp.new(organization, double_github_app_config.deep_merge(extra_config))
    end

    def double_github_app_config
      YAML.load_file('test/dummy/config/secrets_double_github_app.yml')
    end
  end

  class GitHubAppsTestOrgTwo < ActiveSupport::TestCase
    setup do
      @organization = "OrgTwo"
      @github = app(@organization)
      @enterprise = app(@organization, domain: 'github.example.com')
      @rails_env = Rails.env
      @token_cache_key = "github:integration:#{@organization.downcase}:access-token"
      Rails.cache.delete(@token_cache_key)
    end

    teardown do
      Rails.env = @rails_env
      Rails.cache.delete(@token_cache_key)
    end

    test "#domain defaults to github.com" do
      assert_equal 'github.com', @github.domain
    end

    test "#url returns the HTTPS url to the github installation" do
      assert_equal 'https://github.example.com', @enterprise.url
      assert_equal 'https://github.example.com/foo/bar', @enterprise.url('/foo/bar')
      assert_equal 'https://github.example.com/foo/bar/baz', @enterprise.url('foo/bar', 'baz')
    end

    test "#new_client retruns an Octokit::Client configured to use the github installation" do
      assert_equal 'https://github.example.com/', @enterprise.new_client.web_endpoint
      assert_equal 'https://github.example.com/api/v3/', @enterprise.new_client.api_endpoint
    end

    test "#oauth_config.last[:client_options] is nil if domain is not overriden" do
      assert_nil @github.oauth_config.last[:client_options][:site]
    end

    test "#oauth_config.last[:client_options] returns Enterprise endpoint if domain is overriden" do
      assert_equal 'https://github.example.com/api/v3/', @enterprise.oauth_config.last[:client_options][:site]
    end

    test "#initialize doesn't raise if given an empty config" do
      assert_nothing_raised do
        GitHubApp.new(@organization, {})
      end
    end

    test "#api_status" do
      stub_request(:get, "https://www.githubstatus.com/api/v2/components.json").to_return(
        status: 200,
        body: %(
          {
            "page":{},
            "components":[
              {
                "id":"brv1bkgrwx7q",
                "name":"API Requests",
                "status":"operational",
                "created_at":"2017-01-31T20:01:46.621Z",
                "updated_at":"2019-07-23T18:41:18.197Z",
                "position":2,
                "description":"Requests for GitHub APIs",
                "showcase":false,
                "group_id":null,
                "page_id":"kctbh9vrtdwd",
                "group":false,
                "only_show_if_degraded":false
              }
            ]
          }
        ),
      )
      assert_equal "operational", app(@organization).api_status[:status]
    end

    test "#github token is refreshed after expiration" do
      Rails.env = 'not_test'
      config = {
        app_id: "test_id",
        installation_id: "test_installation_id",
        private_key: "test_private_key",
      }
      initial_token = OpenStruct.new(
        token: "some_initial_github_token",
        expires_at: Time.now.utc + 60.minutes,
      )
      second_token = OpenStruct.new(
        token: "some_new_github_token",
        expires_at: initial_token.expires_at + 60.minutes,
      )
      auth_payload = "test_auth_payload"

      GitHubApp.any_instance.expects(:authentication_payload).twice.returns(auth_payload)
      valid_app = app(@organization, config)

      freeze_time do
        Octokit::Client
          .any_instance
          .expects(:create_app_installation_access_token).twice.with(config[:installation_id], anything)
          .returns(initial_token, second_token)

        initial_token = valid_app.token
        initial_cached_token = Rails.cache.fetch(@token_cache_key)
        assert_equal initial_token, initial_cached_token.to_s

        travel 5.minutes
        assert_equal initial_token, valid_app.token

        travel_to initial_cached_token.expires_at + 5.minutes
        assert_equal second_token.token, valid_app.token
      end
    end

    test "#github token is refreshed in refresh window before expiry" do
      Rails.env = 'not_test'
      config = {
        app_id: "test_id",
        installation_id: "test_installation_id",
        private_key: "test_private_key",
      }
      initial_token = OpenStruct.new(
        token: "some_initial_github_token",
        expires_at: Time.now.utc + 60.minutes,
      )
      second_token = OpenStruct.new(
        token: "some_new_github_token",
        expires_at: initial_token.expires_at + 60.minutes,
      )
      auth_payload = "test_auth_payload"

      GitHubApp.any_instance.expects(:authentication_payload).twice.returns(auth_payload)
      valid_app = app(@organization, config)

      freeze_time do
        Octokit::Client
          .any_instance
          .expects(:create_app_installation_access_token).twice.with(config[:installation_id], anything)
          .returns(initial_token, second_token)

        initial_token = valid_app.token
        initial_cached_token = Rails.cache.fetch(@token_cache_key)
        assert_equal initial_token, initial_cached_token.to_s

        # Travel forward, but before the token is refreshed, so the cached value should be the same.
        travel 40.minutes
        assert_equal initial_token, valid_app.token

        # Travel to when the token should refresh, but is not expired, which should result in our cache.fetch update block.
        travel 15.minutes
        updated_token = valid_app.token
        assert_not_equal initial_token, updated_token

        cached_token = Rails.cache.fetch(@token_cache_key)
        assert_operator cached_token.expires_at, :>, initial_cached_token.expires_at
      end
    end

    test "#github token is missing refresh_at field" do
      # $debugging = true
      Rails.env = 'not_test'
      config = {
        app_id: "test_id",
        installation_id: "test_installation_id",
        private_key: "test_private_key",
      }
      initial_cached_token = Shipit::GitHubApp::Token.new("some_initial_github_token", Time.now.utc - 1.minute)
      initial_cached_token.instance_variable_set(:@refresh_at, nil)

      second_token = OpenStruct.new(
        token: "some_new_github_token",
        expires_at: initial_cached_token.expires_at + 60.minutes,
      )
      auth_payload = "test_auth_payload"

      GitHubApp.any_instance.expects(:authentication_payload).returns(auth_payload)
      valid_app = app(@organization, config)

      freeze_time do
        valid_app.instance_variable_set(:@token, initial_cached_token)
        Rails.cache.write(@token_cache_key, initial_cached_token, expires_in: 1.minute)

        Octokit::Client
          .any_instance
          .expects(:create_app_installation_access_token).with(config[:installation_id], anything)
          .returns(second_token)

        first_token = valid_app.token

        first_cached_token = Rails.cache.fetch(@token_cache_key)
        assert_equal first_token, first_cached_token.to_s

        travel_to first_cached_token.expires_at + 5.minutes
        new_token = valid_app.token

        assert_equal second_token.token, new_token
      end
    end

    private

    def app(organization, extra_config = {})
      GitHubApp.new(organization, double_github_app_config.deep_merge(extra_config))
    end

    def double_github_app_config
      YAML.load_file('test/dummy/config/secrets_double_github_app.yml')
    end
  end
end
