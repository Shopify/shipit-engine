require 'test_helper'

class Api::StacksControllerTest < ActionController::TestCase
  setup do
    authenticate!
  end

  test "#index returns a list of stacks" do
    stack = Stack.last

    get :index
    assert_response :ok
    assert_json '0.id', stack.id
  end

  test "#index is paginable" do
    get :index, page_size: 1
    assert_json do |list|
      assert_instance_of Array, list
      assert_equal 1, list.size

      stack_id = list.last['id']
      assert_link 'next', api_stacks_url(since: stack_id, page_size: 1)
      assert_link 'first', api_stacks_url(page_size: 1)
    end
  end

  test "the `next` link is not provided when the last page is reached" do
    get :index, page_size: Stack.count
    assert_no_link 'next'
  end
end
