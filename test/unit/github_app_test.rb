require 'test_helper'

module Shipit
  class GitHubAppTest < ActiveSupport::TestCase
    setup do
      @github = app
      @enterprise = app(domain: 'github.example.com')
    end

    test "#initialize doesn't raise if given an empty config" do
      assert_nothing_raised do
        GitHubApp.new({})
      end
    end

    test "#domain defaults to github.com" do
      assert_equal 'github.com', @github.domain
    end

    test "#url returns the HTTPS url to the github installation" do
      assert_equal 'https://github.example.com', @enterprise.url
      assert_equal 'https://github.example.com/foo/bar', @enterprise.url('/foo/bar')
      assert_equal 'https://github.example.com/foo/bar/baz', @enterprise.url('foo/bar', 'baz')
    end

    test "#oauth_config.last[:client_options] is nil if domain is not overriden" do
      assert_nil @github.oauth_config.last[:client_options][:site]
    end

    test "#oauth_config.last[:client_options] returns Enterprise endpoint if domain is overriden" do
      assert_equal 'https://github.example.com/api/v3/', @enterprise.oauth_config.last[:client_options][:site]
    end

    private

    def app(extra_config = {})
      GitHubApp.new(default_config.deep_merge(extra_config))
    end

    def default_config
      Rails.application.secrets.github.deep_dup
    end
  end
end
