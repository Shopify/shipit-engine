require 'test_helper'

class DeploysControllerTest < ActionController::TestCase

  setup do
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit)
    @commit = commits(:second)
  end

  test ":show is success" do
    get :show, stack_id: @stack.id, id: @deploy.id
    assert_response :success
  end

  test ":create persit a new deploy" do
    assert_difference '@stack.deploys.count', +1 do
      post :create, stack_id: @stack.id, deploy: {until_commit_id: @commit.id}
    end
  end

  test ":create redirec to the new deploy" do
    post :create, stack_id: @stack.id, deploy: {until_commit_id: @commit.id}
    new_deploy = Deploy.last
    assert_redirected_to [@stack, new_deploy]
  end

end
