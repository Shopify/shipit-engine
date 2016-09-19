require 'test_helper'

module Shipit
  module Api
    class DeploysControllerTest < ActionController::TestCase
      setup do
        authenticate!
        @user = shipit_users(:walrus)
        @stack = shipit_stacks(:shipit)
        @commit = shipit_commits(:fifth)
      end

      test "#create triggers a new deploy for the stack" do
        assert_difference -> { @stack.deploys.count }, 1 do
          post :create, params: {stack_id: @stack.to_param, sha: @commit.sha}
        end
        assert_response :accepted
        assert_json 'status', 'pending'
      end

      test "#create triggers a new deploy for whitelisted variables" do
        correct_env = {'SAFETY_DISABLED' => 1}
        post :create, params: {stack_id: @stack.to_param, sha: @commit.sha, env: correct_env}
        assert_response :accepted
        assert_json 'type', 'deploy'
        assert_json 'status', 'pending'
      end

      test "#create refuses to trigger a new deploy with incorrect variables" do
        incorrect_env = {'DANGEROUS_VARIABLE' => 1}
        post :create, params: {stack_id: @stack.to_param, sha: @commit.sha, env: incorrect_env}
        assert_response :unprocessable_entity
        assert_json 'message', 'Variables DANGEROUS_VARIABLE have not been whitelisted'
      end

      test "#create use the claimed user as author" do
        request.headers['X-Shipit-User'] = @user.login
        post :create, params: {stack_id: @stack.to_param, sha: @commit.sha}
        deploy = Deploy.last
        deploy.user == @user
      end

      test "#create renders a 422 if the sha isn't found" do
        post :create, params: {stack_id: @stack.to_param, sha: '123443543545'}
        assert_response :unprocessable_entity
        assert_json 'errors', 'sha' => ['Unknown revision']
      end

      test "#create renders a 422 if the sha format is invalid" do
        post :create, params: {stack_id: @stack.to_param, sha: '1'}
        assert_response :unprocessable_entity
        assert_json 'errors', 'sha' => ['is too short (minimum is 6 characters)']
      end

      test "#create refuses to deploy locked stacks" do
        @stack.update!(lock_reason: 'Something broken')

        assert_no_difference -> { @stack.deploys.count } do
          post :create, params: {stack_id: @stack.to_param, sha: @commit.sha}
        end
        assert_response :unprocessable_entity
        assert_json 'errors.force', ["Can't deploy a locked stack"]
      end

      test "#create accepts to deploy locked stacks if force mode is enabled" do
        @stack.update!(lock_reason: 'Something broken')

        assert_difference -> { @stack.deploys.count }, 1 do
          post :create, params: {stack_id: @stack.to_param, sha: @commit.sha, force: 'true'}
        end
        assert_response :accepted
        assert_json 'status', 'pending'
      end
    end
  end
end
