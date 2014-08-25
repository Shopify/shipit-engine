require 'test_helper'

class RollbacksControllerTest < ActionController::TestCase

  setup do
    Deploy.where(status: %w(running pending)).update_all(status: 'success')
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit)
    session[:user_id] = users(:walrus).id
  end

  test ":create persists a new rollback" do
    assert_difference '@stack.rollbacks.count', +1 do
      post :create, stack_id: @stack.to_param, rollback: {parent_id: @deploy.id}
    end
  end

  test ":create redirects to the new deploy" do
    post :create, stack_id: @stack.to_param, rollback: {parent_id: @deploy.id}
    assert_redirected_to stack_deploy_path(@stack, Rollback.last)
  end

end
