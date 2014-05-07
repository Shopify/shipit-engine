require 'test_helper'

class MenuTest < ActiveSupport::TestCase
  setup do
    @stacks = [stacks(:shipit)]
    @menu   = Menu.new(@stacks)
    @owner  = @menu.owners.first
    @repo   = @owner.repos.first

    Rails.cache.clear
  end

  test '#stacks returns the stacks' do
    assert_equal @stacks, @menu.stacks
  end

  test '#owners' do
    assert_equal 1, @menu.owners.count
  end

  test 'Owner has a name' do
    assert_equal 'shopify', @owner.name
  end

  test 'Owner has repos' do
    assert_equal [@repo], @owner.repos
  end

  test 'Repo has a name' do
    assert_equal 'shipit2', @repo.name
  end

  test 'Repo has stacks' do
    assert_equal @stacks, @repo.stacks
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
