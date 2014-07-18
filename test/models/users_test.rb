require 'test_helper'

class UsersTest < ActiveSupport::TestCase

  setup do
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

  test "all_ids_of_users returns an array of ids for each user" do
    user = users(:bob)
    result = User.all_ids_of_users([user.id])
    assert_equal result.class, User::ActiveRecord_Relation

    expected_values = [result.first.github_id, result.first.name, result.first.email]
    values = [user.github_id, user.name, user.email]
    assert_equal expected_values, values
  end

  private

  def fetch_user
    User.find_or_create_from_github(@github_user)
  end

end
