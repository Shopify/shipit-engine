require 'test_helper'

class Api::StacksControllerTest < ActionController::TestCase
  setup do
    authenticate!
    @stack = stacks(:shipit)
  end

  test "#index returns a list of stacks" do
    stack = Stack.last

    get :index
    assert_response :ok
    assert_json '0.id', stack.id
    assert_json do |stacks|
      assert_equal 3, stacks.size
    end
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

  test "an api client scoped to a stack will only see that one stack" do
    authenticate!(:here_come_the_walrus)
    get :index
    assert_json do |stacks|
      assert_equal 1, stacks.size
    end
  end

  test "a request with insufficient permissions will render a 403" do
    @client.update!(permissions: [])
    get :index
    assert_response :forbidden
    assert_json 'message', 'This operation requires the `read:stack` permission'
  end

  test "#show renders the stack" do
    get :show, id: @stack.to_param
    assert_response :ok
    assert_json 'id', @stack.id
  end
end
