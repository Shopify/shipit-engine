require 'test_helper'

class UsersTest < ActiveSupport::TestCase
  setup do
    @user = users(:walrus)
    rels = {self: stub(href: 'https://api.github.com/user/george')}
    @github_user = stub(id: 42, name: 'George Abitbol', login: 'george', email: 'george@cyclim.se', rels: rels)
  end

  test "find_or_create_from_github persist a new user if he is unknown" do
    assert_difference 'User.count', +1 do
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

  test "#identifiers_for_ping returns a hash with the user's github_id, name, email and github_login" do
    user = users(:bob)
    expected_ouput = {github_id: user.github_id, name: user.name, email: user.email, github_login: user.login}
    assert_equal expected_ouput, user.identifiers_for_ping
  end

  test "#refresh_from_github! update the user with the latest data from GitHub's API" do
    Shipster.github_api.expects(:user).with('walrus').returns(@github_user)
    @user.refresh_from_github!
    @user.reload

    assert_equal 'George Abitbol', @user.name
    assert_equal 'george@cyclim.se', @user.email
  end

  test "#refresh_from_github! can identify renamed users and update commits and tasks accordingly" do
    user = users(:bob)
    user.update!(github_id: @github_user.id)
    commit = user.authored_commits.last

    Shipster.github_api.expects(:user).with(user.login).raises(Octokit::NotFound)
    Shipster.github_api.expects(:commit).with(commit.github_repo_name, commit.sha).returns(mock(author: @github_user))

    assert_equal 'bob', user.login

    user.refresh_from_github!
    user.reload

    assert_equal 'george', user.login
    assert_equal 'George Abitbol', user.name
    assert_equal 'george@cyclim.se', user.email
  end

  private

  def fetch_user
    User.find_or_create_from_github(@github_user)
  end
end
