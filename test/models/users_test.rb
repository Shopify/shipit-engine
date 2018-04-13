require 'test_helper'

module Shipit
  class UsersTest < ActiveSupport::TestCase
    setup do
      @user = shipit_users(:walrus)
      @github_user = stub(
        id: 42,
        name: 'George Abitbol',
        login: 'george',
        email: 'george@cyclim.se',
        avatar_url: 'https://avatars.githubusercontent.com/u/42?v=3',
        url: 'https://api.github.com/user/george',
      )
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
      user = User.find_or_create_from_github(@minimal_github_user)
      assert_equal @minimal_github_user.login, user.login
    end

    test "#identifiers_for_ping returns a hash with the user's github_id, name, email and github_login" do
      user = shipit_users(:bob)
      expected_ouput = {github_id: user.github_id, name: user.name, email: user.email, github_login: user.login}
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
      # See: https://github.com/attr-encrypted/attr_encrypted/blob/53266da546a21afaa1f1b93a461b912f4ccf363b/README.md#upgrading-from-attr_encrypted-v2x-to-v3x
      legacy = shipit_users(:legacy)
      assert_not_nil legacy.encrypted_github_access_token
      assert_not_nil legacy.encrypted_github_access_token_iv

      assert_nil legacy.github_access_token
      legacy.reload
      assert_nil legacy.encrypted_github_access_token
      assert_nil legacy.encrypted_github_access_token_iv

      legacy.update!(github_access_token: 't0k3n')
      legacy.reload
      assert_equal 't0k3n', legacy.github_access_token
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

    private

    def fetch_user
      User.find_or_create_from_github(@github_user)
    end
  end
end
