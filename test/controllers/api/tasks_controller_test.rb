# frozen_string_literal: true

require 'test_helper'

module Shipit
  module Api
    class TasksControllerTest < ApiControllerTestCase
      setup do
        @stack = shipit_stacks(:shipit)
        @user = shipit_users(:walrus)
        authenticate!
      end

      test "#index returns a list of tasks" do
        task = @stack.tasks.last

        get :index, params: { stack_id: @stack.to_param }
        assert_response :ok
        assert_json '0.id', task.id
      end

      test "#show returns a task" do
        task = @stack.tasks.last

        get :show, params: { stack_id: @stack.to_param, id: task.id }
        assert_response :ok
        assert_json 'id', task.id
      end

      test "#trigger returns 404 with unknown task" do
        post :trigger, params: { stack_id: @stack.to_param, task_name: 'shave_the_yak' }
        assert_response :not_found
      end

      test "#trigger triggers a custom task" do
        post :trigger, params: { stack_id: @stack.to_param, task_name: 'restart' }
        assert_response :accepted
        assert_json 'type', 'task'
        assert_json 'status', 'pending'

        expected_env = {
          "FOO" => "1",
          "BAR" => "0",
        }
        assert_equal expected_env, Shipit::Task.last.env
      end

      test "#trigger refuses to trigger a task with tasks not whitelisted" do
        env = { 'DANGEROUS_VARIABLE' => 'bar' }
        post :trigger, params: { stack_id: @stack.to_param, task_name: 'restart', env: }
        assert_response :unprocessable_entity
        assert_json 'message', 'Variables DANGEROUS_VARIABLE have not been whitelisted'
      end

      test "#trigger triggers a task with only whitelisted env variables" do
        env = { 'FOO' => 'bar' }
        post :trigger, params: { stack_id: @stack.to_param, task_name: 'restart', env: }
        assert_response :accepted
        assert_json 'type', 'task'
        assert_json 'status', 'pending'

        expected_env = {
          "FOO" => "bar",
          "BAR" => "0",
        }
        assert_equal expected_env, Shipit::Task.last.env
      end

      test "#trigger triggers a task with explicitly passed and default variables" do
        env = { 'WALRUS' => 'overridden value' }
        post :trigger, params: { stack_id: @stack.to_param, task_name: 'restart', env: }
        assert_response :accepted

        # FOO and BAR are variables with a default value
        expected_env = {
          "FOO" => "1",
          "BAR" => "0",
          "WALRUS" => "overridden value",
        }
        assert_equal expected_env, Shipit::Task.last.env
      end

      test "#trigger returns a 404 when the task doesn't exist" do
        post :trigger, params: { stack_id: @stack.to_param, task_name: 'doesnt_exist' }
        assert_response :not_found
      end

      test "#trigger returns 409 when a task is already running" do
        shipit_deploys(:shipit_running).update!(allow_concurrency: false, status: 'running')
        assert_predicate @stack, :active_task?
        post :trigger, params: { stack_id: @stack.to_param, task_name: 'restart' }
        assert_response :conflict
        assert_json 'message', 'A task is already running.'
      end

      test "#trigger fails when user does not have deploy permission" do
        @client.permissions.delete('deploy:stack')
        @client.save!

        assert_no_difference 'Task.count' do
          post :trigger, params: { stack_id: @stack.to_param, task_name: 'restart' }
        end

        assert_response :forbidden
        assert_json 'message', 'This operation requires the `deploy:stack` permission'
      end

      test "#abort aborts the task" do
        task = shipit_deploys(:shipit_running)
        task.ping

        put :abort, params: { stack_id: @stack.to_param, id: task.id }

        assert_response :accepted
        assert_equal 'aborting', task.reload.status
      end

      test "#abort sets `aborted_by` to the current user" do
        task = shipit_deploys(:shipit_running)
        task.ping
        request.headers['X-Shipit-User'] = @user.login

        put :abort, params: { stack_id: @stack.to_param, id: task.id }

        assert_equal task.reload.aborted_by, @user
      end

      test "#abort responds with method_not_allowed if the task is not currently running" do
        task = shipit_deploys(:shipit_aborted)
        task.ping
        put :abort, params: { stack_id: @stack.to_param, id: task.id }

        assert_response :method_not_allowed
        assert_json 'message', 'This task is not currently running.'
      end

      test "#abort fails when user does not have deploy permission" do
        @client.permissions.delete('deploy:stack')
        @client.save!
        task = shipit_deploys(:shipit_running)
        task.ping

        assert_no_difference 'Task.count' do
          put :abort, params: { stack_id: @stack.to_param, id: task.id }
        end

        assert_response :forbidden
        assert_json 'message', 'This operation requires the `deploy:stack` permission'
      end
    end
  end
end
