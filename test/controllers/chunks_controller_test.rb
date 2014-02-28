require 'test_helper'

class ChunksControllerTest < ActionController::TestCase

  setup do
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit)
    @last_chunk = @deploy.chunks.last
  end

  test ":index is success" do
    get :index, stack_id: @stack.to_param, deploy_id: @deploy.id, format: :json
    assert_response :success
    assert_equal @response.body, @deploy.chunks.to_json
  end

  test ":index with last_id" do
    get :index, stack_id: @stack.to_param, deploy_id: @deploy.id, last_id: @last_chunk.id, format: :json
    assert_response :success
    assert_equal @response.body, '[]'
  end

  test ":tail" do
    get :tail, stack_id: @stack.to_param, deploy_id: @deploy.id, last_id: @last_chunk.id, format: :json
    assert_response :success
    assert_equal JSON.parse(@response.body).keys, ['url', 'deploy', 'chunks']
  end
end
