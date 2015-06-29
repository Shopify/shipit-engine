require 'test_helper'

class ChunksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit)
    @last_chunk = @deploy.chunks.last
    session[:user_id] = users(:walrus).id
  end

  test ":index is success" do
    get :index, stack_id: @stack.to_param, task_id: @deploy.id, format: :json
    assert_response :success
    assert_equal @deploy.chunks.to_json, @response.body
  end

  test ":index with last_id" do
    get :index, stack_id: @stack.to_param, task_id: @deploy.id, last_id: @last_chunk.id, format: :json
    assert_response :success
    assert_equal '[]', @response.body
  end

  test ":tail" do
    get :tail, stack_id: @stack.to_param, task_id: @deploy.id, last_id: @last_chunk.id, format: :json
    assert_response :success
    assert_equal %w(url status chunks), JSON.parse(@response.body).keys
  end
end
