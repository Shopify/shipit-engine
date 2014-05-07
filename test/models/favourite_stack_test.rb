require 'test_helper'

class FavouriteStackTest < ActiveSupport::TestCase
  test 'with no user, is invalid' do
    fs      = favourite_stacks(:one)
    fs.user = nil

    refute fs.valid?
    assert_equal ["can't be blank"], fs.errors[:user]
  end

  test 'with no stack, is invalid' do
    fs       = favourite_stacks(:one)
    fs.stack = nil

    refute fs.valid?
    assert_equal ["can't be blank"], fs.errors[:stack]
  end

  test 'the stack_id and user_id must be unique' do
    existing = favourite_stacks(:one)
    other    = FavouriteStack.create(user: existing.user, stack: existing.stack)

    refute other.persisted?
    assert_equal ['is already favourited.'], other.errors[:stack_id]
  end
end
