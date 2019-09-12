require 'test_helper'

module Shipit
  class DeploysControllerTest < ActionController::TestCase
    setup do
      Deploy.where(status: %w(running pending)).update_all(status: 'success')
      @stack = shipit_stacks(:shipit)
      @deploy = shipit_deploys(:shipit)
      @commit = shipit_commits(:second)
      @user = shipit_users(:walrus)
      session[:user_id] = @user.id
    end

    test ":show is success" do
      get :show, params: {stack_id: @stack.to_param, id: @stack.deploys.last.id}
      assert_response :success
    end

    test "deploys can be observed as raw text" do
      get :show, params: {stack_id: @stack, id: @deploy.id, format: 'txt'}
      assert_response :success
      assert_equal("text/plain", @response.media_type)
    end

    test ":new is success" do
      get :new, params: {stack_id: @stack.to_param, sha: @commit.sha}
      assert_response :success
    end

    test ":new works for not yet deployed stacks" do
      @stack = shipit_stacks(:undeployed_stack)
      get :new, params: {stack_id: @stack.to_param, sha: @stack.commits.last.sha}
    end

    test ":new shows a warning if a deploy is already running" do
      shipit_deploys(:shipit_running).update!(allow_concurrency: false, status: 'running')

      get :new, params: {stack_id: @stack.to_param, sha: @commit.sha}
      assert_response :success
      assert_select '.warning.concurrent-deploy h2' do |elements|
        assert_equal 'Lando Walrussian is already deploying!', elements.first.text
      end
      assert_select '#new_deploy #force', 1
    end

    test ":create persists a new deploy" do
      assert_difference '@stack.deploys.count', 1 do
        post :create, params: {stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}}
      end
    end

    test ":create can receive an :env hash" do
      env = {'SAFETY_DISABLED' => '1'}
      post :create, params: {stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id, env: env}}
      new_deploy = Deploy.last
      assert_equal env, new_deploy.env
    end

    test ":create ignore :env keys not declared in the deploy spec" do
      post :create, params: {stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id, env: {'H4X0R' => '1'}}}
      new_deploy = Deploy.last
      assert_equal({}, new_deploy.env)
    end

    test ":create with `force` option ignore the active deploys" do
      shipit_deploys(:shipit_running).update_column(:status, 'running')

      assert_difference '@stack.deploys.count', 1 do
        post :create, params: {stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}, force: 'true'}
      end
    end

    test ":create redirect back to :new with a warning if there is an active deploy" do
      shipit_deploys(:shipit_running).update!(allow_concurrency: false, status: 'running')

      assert_no_difference '@stack.deploys.count' do
        post :create, params: {stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}}
      end
      assert_redirected_to new_stack_deploy_path(@stack, sha: @commit.sha)
    end

    test ":create redirects to the new deploy" do
      post :create, params: {stack_id: @stack.to_param, deploy: {until_commit_id: @commit.id}}
      new_deploy = Deploy.last
      assert_redirected_to stack_deploy_path(@stack, new_deploy)
    end

    test ":rollback is success" do
      get :rollback, params: {stack_id: @stack.to_param, id: @deploy.id}
      assert_response :success
    end

    test ":rollback shows a warning if a deploy is already running" do
      shipit_deploys(:shipit_running).update!(allow_concurrency: false, status: 'running')

      get :rollback, params: {stack_id: @stack.to_param, id: @deploy.id}
      assert_response :success
      assert_select '.warning.concurrent-deploy h2' do |elements|
        assert_equal 'Lando Walrussian is already deploying!', elements.first.text
      end
      assert_select '#new_rollback #force', 1
    end

    test ":rollback button shows deploy and commit ids" do
      previous_deploy = @stack.deploys.second_to_last
      previous_deploy.status = "success"
      previous_deploy.type = "Shipit::Deploy"
      previous_deploy.since_commit_id = 1
      previous_deploy.until_commit_id = 2
      previous_deploy.save

      latest_deploy = @stack.deploys.last
      latest_deploy.status = "running"
      latest_deploy.type = "Shipit::Deploy"
      latest_deploy.since_commit_id = 3
      latest_deploy.until_commit_id = 4
      latest_deploy.save

      rollback_commit = @stack.commits.where(id: 2).first

      get :show, params: {stack_id: @stack, id: latest_deploy.id, format: 'html'}

      expected_result = "Abort and Rollback to <span class=\"short-sha-no-bg\">#{rollback_commit.short_sha}</span>"
      expected_rolling_back_element = "Aborting with Rollback... to <span class=\"short-sha-no-bg\">#{rollback_commit.short_sha}</span>"

      assert_select 'span.caption--ready', {html: expected_result}, "rollback button element was not found, or did not match the expected result of '#{expected_result}'"
      assert_select 'span.caption--pending', {html: expected_rolling_back_element}, "ready rollback button element was not found, or did not match the expected result of '#{expected_rolling_back_element}'"
    end

    test ":rollback (regression) works correctly when a previous deploy is not found" do
      rollback_commit_id = 3
      latest_deploy = @stack.deploys.last
      latest_deploy.status = "running"
      latest_deploy.type = "Shipit::Deploy"
      latest_deploy.since_commit_id = rollback_commit_id
      latest_deploy.until_commit_id = 4
      latest_deploy.save

      @stack.deploys.where.not(id: latest_deploy.id).delete_all

      rollback_commit = @stack.commits.where(id: rollback_commit_id).take

      get :show, params: {stack_id: @stack, id: latest_deploy.id, format: 'html'}

      expected_result = "Abort and Rollback to <span class=\"short-sha-no-bg\">#{rollback_commit.short_sha}</span>"
      expected_rolling_back_element = "Aborting with Rollback... to <span class=\"short-sha-no-bg\">#{rollback_commit.short_sha}</span>"

      assert_select 'span.caption--ready', {html: expected_result}, "rollback button element was not found, or did not match the expected result of '#{expected_result}'"
      assert_select 'span.caption--pending', {html: expected_rolling_back_element}, "ready rollback button element was not found, or did not match the expected result of '#{expected_rolling_back_element}'"
    end

    test ":revert redirect to the proper rollback page" do
      get :revert, params: {stack_id: @stack.to_param, id: shipit_deploys(:shipit2).id}
      assert_redirected_to rollback_stack_deploy_path(@stack, shipit_deploys(:shipit))
    end
  end
end
