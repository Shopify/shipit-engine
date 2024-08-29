# frozen_string_literal: true
require 'test_helper'

module Shipit
  module Api
    class RollbacksControllerTest < ApiControllerTestCase
      setup do
        authenticate!
        @user = shipit_users(:walrus)
        @stack = shipit_stacks(:shipit)
        @commit = shipit_commits(:fourth)
      end

      test "#create triggers a new rollback for the stack" do
        assert_difference -> { @stack.deploys.count }, 1 do
          post :create, params: { stack_id: @stack.to_param, sha: @commit.sha }
        end
        assert_response :accepted
        assert_json 'status', 'pending'
      end

      test "#create triggers a new rollback for whitelisted variables" do
        correct_env = { 'SAFETY_DISABLED' => 1 }
        post :create, params: { stack_id: @stack.to_param, sha: @commit.sha, env: correct_env }
        assert_response :accepted
        assert_json 'type', 'rollback'
        assert_json 'status', 'pending'
      end

      test "#create refuses to trigger a new rollback with incorrect variables" do
        incorrect_env = { 'DANGEROUS_VARIABLE' => 1 }
        post :create, params: { stack_id: @stack.to_param, sha: @commit.sha, env: incorrect_env }
        assert_response :unprocessable_entity
        assert_json 'message', 'Variables DANGEROUS_VARIABLE have not been whitelisted'
      end

      test "#create use the claimed user as author" do
        request.headers['X-Shipit-User'] = @user.login
        post :create, params: { stack_id: @stack.to_param, sha: @commit.sha }
        rollback = Rollback.last
        assert_equal @user, rollback.user
      end

      test "#create normalises the claimed user" do
        request.headers['X-Shipit-User'] = @user.login.swapcase
        post :create, params: { stack_id: @stack.to_param, sha: @commit.sha }
        rollback = Rollback.last
        assert_equal @user, rollback.user
      end

      test "#create renders a 422 if the sha isn't found" do
        post :create, params: { stack_id: @stack.to_param, sha: '123443543545' }
        assert_response :unprocessable_entity
        assert_json 'errors', 'sha' => ['Unknown revision']
      end

      test "#create renders a 422 if the sha format is invalid" do
        post :create, params: { stack_id: @stack.to_param, sha: '1' }
        assert_response :unprocessable_entity
        assert_json 'errors', 'sha' => ['is too short (minimum is 6 characters)']
      end

      test "#create renders a 422 if deploy attached to sha isn't found" do
        post :create, params: { stack_id: @stack.to_param, sha: shipit_commits(:fifth).sha }
        assert_response :unprocessable_entity
        assert_json 'errors', 'sha' => ['Cant find associated deploy']
      end

      test "#create refuses to rollback on locked stacks" do
        @stack.update!(lock_reason: 'Something broken')

        assert_no_difference -> { @stack.deploys.count } do
          post :create, params: { stack_id: @stack.to_param, sha: @commit.sha }
        end
        assert_response :unprocessable_entity
        assert_json 'errors.force', ["Can't rollback a locked stack"]
      end

      test "#create rollbacks on locked stack if force mode is enabled" do
        @stack.update!(lock_reason: 'Something broken')

        assert_difference -> { @stack.deploys.count }, 1 do
          post :create, params: { stack_id: @stack.to_param, sha: @commit.sha, force: 'true' }
        end
        assert_response :accepted
        assert_json 'status', 'pending'
      end

      test "#create refuses to rollback if active task" do
        @stack.deploys.last.update!(status: 'running')

        assert_no_difference -> { @stack.deploys.count } do
          post :create, params: { stack_id: @stack.to_param, sha: @commit.sha }
        end
        assert_response :unprocessable_entity
        assert_json 'errors.force', ["Can't rollback, deploy in progress"]
      end

      test "#create aborts active task and sets rollback to" do
        last_deploy = @stack.deploys.last
        last_deploy.update!(status: 'running')

        assert_no_difference -> { @stack.deploys.count } do
          post :create, params: { stack_id: @stack.to_param, sha: @commit.sha, force: 'true' }
        end
        last_deploy.reload
        assert_response :accepted
        refute_predicate last_deploy, :active?
        assert_json 'rollback_once_aborted_to.revision.sha', @commit.sha
        assert last_deploy.rollback_once_aborted?
      end
    end
  end
end
