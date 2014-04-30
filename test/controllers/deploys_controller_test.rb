require 'test_helper'

class DeploysControllerTest < ActionController::TestCase

  setup do
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit)
    @commit = commits(:second)
  end

  test ":show is success" do
    get :show, stack_id: @stack.to_param, id: @deploy.id
    assert_response :success
  end

  test ":show renders a partial" do
    get :show, stack_id: @stack.to_param, id: @deploy.id, partial: 1

    assert_select "html", false
    assert_select "li.deploy"
  end

  test ":create persists a new deploy" do
    assert_difference '@stack.deploys.count', +1 do
      post :create, stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}
   end
  end

  test ":create redirects to the new deploy" do
    post :create, stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}
    new_deploy = Deploy.last
    assert_redirected_to stack_deploy_path(@stack, new_deploy)
  end
end
