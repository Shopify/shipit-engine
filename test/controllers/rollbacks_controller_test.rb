require 'test_helper'

module Shipit
  class RollbacksControllerTest < ActionController::TestCase
    setup do
      Deploy.where(status: %w(running pending)).update_all(status: 'success')
      @stack = shipit_stacks(:shipit)
      @deploy = shipit_deploys(:shipit)
      session[:user_id] = shipit_users(:walrus).id
    end

    test ":create persists a new rollback" do
      assert_difference '@stack.rollbacks.count', 1 do
        post :create, params: {stack_id: @stack.to_param, rollback: {parent_id: @deploy.id}}
      end
    end

    test ":create can receive an :env hash" do
      env = {'SAFETY_DISABLED' => '1'}
      post :create, params: {stack_id: @stack.to_param, rollback: {parent_id: @deploy.id, env: env}}
      new_rollback = Rollback.last
      assert_equal env, new_rollback.env
    end

    test ":create ignore :env keys not declared in the deploy spec" do
      post :create, params: {stack_id: @stack.to_param, rollback: {parent_id: @deploy.id, env: {'H4X0R' => '1'}}}
      new_rollback = Rollback.last
      assert_equal({}, new_rollback.env)
    end

    test ":create redirects to the new deploy" do
      post :create, params: {stack_id: @stack.to_param, rollback: {parent_id: @deploy.id}}
      assert_redirected_to stack_deploy_path(@stack, Rollback.last)
    end

    test ":create locks deploys" do
      post :create, params: {stack_id: @stack.to_param, rollback: {parent_id: @deploy.id}}
      assert @stack.reload.locked?
    end

    test ":create redirects back to the :new page if there is an active deploy" do
      shipit_deploys(:shipit_running).update_column(:status, 'running')
      assert_no_difference '@stack.deploys.count' do
        post :create, params: {stack_id: @stack.to_param, rollback: {parent_id: @deploy.id}}
      end
      assert_redirected_to rollback_stack_deploy_path(@stack, @deploy)
    end

    test ":create with `force` option ignore the active deploys" do
      shipit_deploys(:shipit_running).update_column(:status, 'running')
      assert_difference '@stack.deploys.count', 1 do
        post :create, params: {stack_id: @stack.to_param, rollback: {parent_id: @deploy.id}, force: 'true'}
      end
      assert_redirected_to stack_deploy_path(@stack, Rollback.last)
    end
  end
end
