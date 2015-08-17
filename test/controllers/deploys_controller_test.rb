require 'test_helper'

class DeploysControllerTest < ActionController::TestCase
  setup do
    Deploy.where(status: %w(running pending)).update_all(status: 'success')
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit)
    @commit = commits(:second)
    session[:user_id] = users(:walrus).id
  end

  test ":show is success" do
    get :show, stack_id: @stack.to_param, id: @deploy.id
    assert_response :success
  end

  test ":new is success" do
    get :new, stack_id: @stack.to_param, sha: @commit.sha
    assert_response :success
  end

  test ":new shows a warning if a deploy is already running" do
    deploys(:shipit_running).update_column(:status, 'running')

    get :new, stack_id: @stack.to_param, sha: @commit.sha
    assert_response :success
    assert_select '.warning.concurrent-deploy h2' do |elements|
      assert_equal 'Lando Walrussian is already deploying!', elements.first.text
    end
    assert_select '#new_deploy #force', 1
  end

  test ":create persists a new deploy" do
    assert_difference '@stack.deploys.count', +1 do
      post :create, stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}
    end
  end

  test ":create can receive an :env hash" do
    env = {'SAFETY_DISABLED' => '1'}
    post :create, stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id, env: env}
    new_deploy = Deploy.last
    assert_equal env, new_deploy.env
  end

  test ":create can receive an :env keys not declared in the deploy spec" do
    post :create, stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id, env: {'H4X0R' => '1'}}
    new_deploy = Deploy.last
    assert_equal({}, new_deploy.env)
  end

  test ":create with `force` option ignore the active deploys" do
    deploys(:shipit_running).update_column(:status, 'running')

    assert_difference '@stack.deploys.count', +1 do
      post :create, stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}, force: true
    end
  end

  test ":create redirect back to :new with a warning if there is an active deploy" do
    deploys(:shipit_running).update_column(:status, 'running')

    assert_no_difference '@stack.deploys.count' do
      post :create, stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}
    end
    assert_redirected_to new_stack_deploy_path(@stack, sha: @commit.sha)
  end

  test ":create redirects to the new deploy" do
    post :create, stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}
    new_deploy = Deploy.last
    assert_redirected_to stack_deploy_path(@stack, new_deploy)
  end

  test ":rollback is success" do
    get :rollback, stack_id: @stack.to_param, id: @deploy.id
    assert_response :success
  end

  test ":rollback shows a warning if a deploy is already running" do
    deploys(:shipit_running).update_column(:status, 'running')

    get :rollback, stack_id: @stack.to_param, id: @deploy.id
    assert_response :success
    assert_select '.warning.concurrent-deploy h2' do |elements|
      assert_equal 'Lando Walrussian is already deploying!', elements.first.text
    end
    assert_select '#new_rollback #force', 1
  end
end
