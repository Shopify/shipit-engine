require 'test_helper'

class MenuTest < ActiveSupport::TestCase

  setup do
    @menu = Menu.new
    @owner = @menu.owners.first
    @repo = @owner.repos.first
    Rails.cache.clear
  end

  test '#owners' do
    assert_equal 1, @menu.owners.count
  end

  test 'Owner have a name' do
    assert_equal 'shopify', @owner.name
  end

  test 'Owner have a repos' do
    assert_equal 1, @owner.repos.count
  end

  test 'Repo have a name' do
    assert_equal 'shipit2', @repo.name
  end

  test 'Repo have stacks' do
    assert_equal 1, @repo.stacks.count
  end

  test '#updated_at is last updated_at stack by default' do
    assert_equal Stack.first.updated_at, @menu.updated_at
  end

  test '#updated_at can be bumped' do
    now = Time.at(42)
    Time.stubs(now: now)
    Menu.bump_cache
    assert_equal now, @menu.updated_at
  end

end
