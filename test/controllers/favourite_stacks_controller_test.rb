require 'test_helper'

class FavouriteStacksControllerTest < ActionController::TestCase
  def favourite_stack
    @favourite_stack ||= favourite_stacks(:one)
  end

  def stack
    @stack ||= favourite_stack.stack
  end

  def user
    @user ||= favourite_stack.user
  end

  def setup
    login_as user
  end

  test '#create with invalid params, redirects to /' do
    FavouriteStack.delete_all

    post :create, stack_id: 'invalid'

    assert_redirected_to '/'
  end

  test '#create with invalid params, sets a flash-error' do
    FavouriteStack.delete_all

    post :create, stack_id: 'invalid'

    assert_equal "Stack can't be blank", flash[:error]
  end

  test '#create with valid params updates "favourites_updated_at" in the user' do
    FavouriteStack.delete_all
    old_timestamp = 1.day.ago
    user.update_attributes(favourites_updated_at: old_timestamp)

    post :create, stack_id: stack.id

    assert user.reload.favourites_updated_at > old_timestamp
  end

  test '#create with valid params, with no referer, redirects to /' do
    FavouriteStack.delete_all

    post :create, stack_id: stack.id

    assert_redirected_to '/'
  end

  test '#create with valid params, with a referer, redirects to the referer' do
    FavouriteStack.delete_all

    @request.env['HTTP_REFERER'] = 'http://test.com/foo'
    post :create, stack_id: stack.id

    assert_redirected_to @request.env['HTTP_REFERER']
  end

  test '#destroy updates "favourites_updated_at" in the user' do
    old_timestamp = 1.day.ago
    user.update_attributes(favourites_updated_at: old_timestamp)

    delete :destroy, stack_id: stack.id

    assert user.reload.favourites_updated_at > old_timestamp
  end

  test '#destroy when destroying fails, redirects back' do
    delete :destroy, stack_id: stack.id

    assert_redirected_to '/'
  end
end
