# frozen_string_literal: true
require 'test_helper'

module Shipit
  class UsersTest < ActiveSupport::TestCase
    setup do
      @previous_preferred_org_emails = Shipit.preferred_org_emails
      @user = shipit_users(:walrus)
      @github_user = stub(
        id: 42,
        name: 'George Abitbol',
        login: 'george',
        email: 'george@cyclim.se',
        avatar_url: 'https://avatars.githubusercontent.com/u/42?v=3',
        url: 'https://api.github.com/user/george',
      )
      @org_domain = "shopify.com"
      @emails_url = "https://api.github.com/user/emails"
      @minimal_github_user = stub(
        id: 43,
        name: nil,
        login: 'peter',
        email: nil,
        avatar_url: 'https://avatars.githubusercontent.com/u/43?v=3',
        url: 'https://api.github.com/user/peter',
        rels: nil,
      )
    end

    teardown do
      Shipit.preferred_org_emails = @previous_preferred_org_emails
    end

    test "find_or_create_from_github persist a new user if he is unknown" do
      assert_difference 'User.count', 1 do
        fetch_user
      end
    end

    test "find_or_create_from_github returns the existing user if he is known" do
      existing = fetch_user

      assert_no_difference 'User.count' do
        assert_equal existing, fetch_user
      end
    end

    test "find_or_create_from_github store the github_id" do
      user = User.find_or_create_from_github(@github_user)
      assert_equal @github_user.id, user.github_id
    end

    test "find_or_create_from_github store the name" do
      user = User.find_or_create_from_github(@github_user)
      assert_equal @github_user.name, user.name
    end

    test "find_or_create_from_github store the email" do
      user = User.find_or_create_from_github(@github_user)
      assert_equal @github_user.email, user.email
    end

    test "find_or_create_from_github store the login" do
      user = User.find_or_create_from_github(@github_user)
      assert_equal @github_user.login, user.login
    end

    test "find_or_create_from_github accepts minimal users without name nor email" do
      Shipit.preferred_org_emails = [].freeze
      user = User.find_or_create_from_github(@minimal_github_user)
      assert_equal @minimal_github_user.login, user.login
    end

    test "find_or_create_from_github selects any email when org email is unspecified" do
      github_org_user = stub(
        id: 42,
        name: 'Jim Jones',
        login: 'jim',
        email: "jim@#{@org_domain}",
        avatar_url: 'https://avatars.githubusercontent.com/u/42?v=3',
        url: 'https://api.github.com/user/jim',
      )

      Shipit.preferred_org_emails = [].freeze
      user = User.find_or_create_from_github(github_org_user)
      assert_equal github_org_user.email, user.email
    end

    test "find_or_create_from_github selects org email for user" do
      Shipit.preferred_org_emails = [@org_domain]
      expected_email = "myuser@#{@org_domain}"

      stub_request(:get, @emails_url).to_return(
        status: %w(200 OK),
        body: [{ email: expected_email }].to_json,
        headers: { "Content-Type" => "application/json" },
      )

      user = User.find_or_create_from_github(@github_user)
      assert_equal expected_email, user.email
    end

    test "find_or_create_from_github selects private and primary org email for user when necessary" do
      Shipit.preferred_org_emails = [@org_domain]
      expected_email = "myuser@#{@org_domain}"
      result_email_records = [
        {
          email: "notmyuser1@#{@org_domain}",
          primary: false,
        },
        {
          email: "notmyuser2@#{@org_domain}",
        },
        {
          email: expected_email,
          primary: true,
        },
      ]

      stub_request(:get, @emails_url).to_return(
        status: %w(200 OK),
        body: result_email_records.to_json,
        headers: { "Content-Type" => "application/json" },
      )

      user = User.find_or_create_from_github(@github_user)
      assert_equal expected_email, user.email
    end

    test "find_or_create_from_github selects no email when org emails are provided but not found" do
      Shipit.preferred_org_emails = [@org_domain]
      result_email_records = [
        {
          email: "notmyuser1@not#{@org_domain}",
          primary: false,
        },
        {
          email: "notmyuser2@not#{@org_domain}",
        },
      ]

      stub_request(:get, @emails_url).to_return(
        status: %w(200 OK),
        body: result_email_records.to_json,
        headers: { "Content-Type" => "application/json" },
      )

      user = User.find_or_create_from_github(@github_user)
      assert_nil user.email
    end

    test "find_or_create_from_github handles user 404" do
      Shipit.preferred_org_emails = [@org_domain]
      Octokit::Client.any_instance.expects(:emails).raises(Octokit::NotFound)
      user = User.find_or_create_from_github(@minimal_github_user)
      assert_nil user.email
    end

    test "find_or_create_from_github handles user 403" do
      Shipit.preferred_org_emails = [@org_domain]
      Octokit::Client.any_instance.expects(:emails).raises(Octokit::Forbidden)
      user = User.find_or_create_from_github(@minimal_github_user)
      assert_nil user.email
    end

    test "find_or_create_from_github handles user 401" do
      Shipit.preferred_org_emails = [@org_domain]
      Octokit::Client.any_instance.expects(:emails).raises(Octokit::Unauthorized)
      user = User.find_or_create_from_github(@minimal_github_user)
      assert_nil user.email
    end

    test "#identifiers_for_ping returns a hash with the user's github_id, name, email and github_login" do
      user = shipit_users(:bob)
      expected_ouput = { github_id: user.github_id, name: user.name, email: user.email, github_login: user.login }
      assert_equal expected_ouput, user.identifiers_for_ping
    end

    test "#refresh_from_github! update the user with the latest data from GitHub's API" do
      Shipit.github.api.expects(:user).with(@user.github_id).returns(@github_user)
      @user.refresh_from_github!
      @user.reload

      assert_equal 'George Abitbol', @user.name
      assert_equal 'george@cyclim.se', @user.email
    end

    test "#refresh_from_github! can identify renamed users and update commits and tasks accordingly" do
      user = shipit_users(:bob)
      user.update!(github_id: @github_user.id)
      commit = user.authored_commits.last

      Shipit.github.api.expects(:user).with(user.github_id).raises(Octokit::NotFound)
      Shipit.github.api.expects(:commit).with(commit.github_repo_name, commit.sha).returns(mock(author: @github_user))

      assert_equal 'bob', user.login

      user.refresh_from_github!
      user.reload

      assert_equal 'george', user.login
      assert_equal 'George Abitbol', user.name
      assert_equal 'george@cyclim.se', user.email
    end

    test "#github_api uses the user's access token" do
      assert_equal @user.github_access_token, @user.github_api.access_token
    end

    test "#github_api fallbacks to Shipit.github.api if the user doesn't have an access_token" do
      assert_equal Shipit.github.api, shipit_users(:bob).github_api
    end

    test "#github_api fallbacks to Shipit.github.api for anonymous users" do
      assert_equal Shipit.github.api, AnonymousUser.new.github_api
    end

    test "users with legacy encrypted access token get their token reset automatically" do
      legacy = shipit_users(:legacy)
      assert_nil legacy.github_access_token

      legacy.update!(github_access_token: 'ghu_t0k3n')
      assert_equal 'ghu_t0k3n', legacy.github_access_token
    end

    test "users with legacy encrypted access token can be updated" do
      legacy = shipit_users(:legacy)
      legacy.update!(github_access_token: 'ghu_t0k3n')
      legacy.reload
      assert_equal 'ghu_t0k3n', legacy.github_access_token
    end

    test "users with legacy encrypted access token can have unrelated attributes updated" do
      legacy = shipit_users(:legacy)
      legacy.update!(name: 'Test')
      assert_equal 'Test', legacy.name
    end

    test "users are always logged_in?" do
      assert_predicate @user, :logged_in?
    end

    test "users are always authorized? if Shipit.github_teams is empty" do
      Shipit.stubs(:github_teams).returns([])
      assert_predicate @user, :authorized?
    end

    test "users are not authorized? if they aren't part of any Shipit.github_teams" do
      Shipit.stubs(:github_teams).returns([shipit_teams(:cyclimse_cooks)])
      refute_predicate @user, :authorized?
    end

    test "users are authorized? if they are part of any Shipit.github_teams" do
      Shipit.stubs(:github_teams).returns([shipit_teams(:shopify_developers)])
      assert_predicate @user, :authorized?
    end

    test "self.find_or_create_author_from_github_commit handles missing users on github" do
      Shipit.github.api.expects(:user).raises(Octokit::NotFound)
      user = shipit_users(:bob)
      github_commit = resource(
        sha: '2adaad1ad30c235d3a6e7981dfc1742f7ecb1e85',
        commit: {
          author: {
            id: user.github_id,
            name: user.name,
            email: user.email,
            date: Time.now.utc,
          },
          committer: {
            name: user.name,
            email: user.email,
            date: Time.now.utc,
          },
          message: "commit to trigger staging build\n\nMerge-Requested-By: missinguser\n",
        },
      )
      found_user = Shipit::User.find_or_create_author_from_github_commit(github_commit)
      assert_equal user, found_user
    end

    test "requires_fresh_login? defaults to false" do
      u = User.new
      refute_predicate u, :requires_fresh_login?
    end

    test "requires_fresh_login? is true for users with legacy github_access_token" do
      @user.update!(github_access_token: 'some_legacy_value')
      assert_predicate @user, :requires_fresh_login?
    end

    test "requires_fresh_login? is false for users with a new format github_access_token" do
      @user.update!(github_access_token: 'ghu_tok3n')
      refute_predicate @user, :requires_fresh_login?
    end

    private

    def fetch_user
      User.find_or_create_from_github(@github_user)
    end
  end
end
