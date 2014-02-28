require 'test_helper'

class ChunksControllerTest < ActionController::TestCase

  setup do
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit)
  end

  test ":show is success" do
    get :index, stack_id: @stack.to_param, deploy_id: @deploy.id, format: :json
    assert_response :success
    assert_equal @response.body, @deploy.chunks.to_json
  end
end
