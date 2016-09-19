require 'test_helper'

module Shipit
  module Api
    class TasksControllerTest < ActionController::TestCase
      setup do
        @stack = shipit_stacks(:shipit)
        authenticate!
      end

      test "#index returns a list of tasks" do
        task = @stack.tasks.last

        get :index, params: {stack_id: @stack.to_param}
        assert_response :ok
        assert_json '0.id', task.id
      end

      test "#show returns a task" do
        task = @stack.tasks.last

        get :show, params: {stack_id: @stack.to_param, id: task.id}
        assert_response :ok
        assert_json 'id', task.id
      end

      test "#trigger triggers a custom task" do
        post :trigger, params: {stack_id: @stack.to_param, task_name: 'restart'}
        assert_response :accepted
        assert_json 'type', 'task'
        assert_json 'status', 'pending'
      end

      test "#trigger refuses to trigger a task with tasks not whitelisted" do
        env = {'DANGEROUS_VARIABLE' => 'bar'}
        post :trigger, params: {stack_id: @stack.to_param, task_name: 'restart', env: env}
        assert_response :unprocessable_entity
        assert_json 'message', 'Variables DANGEROUS_VARIABLE have not been whitelisted'
      end

      test "#trigger triggers a task with only whitelisted env variables" do
        env = {'FOO' => 'bar'}
        post :trigger, params: {stack_id: @stack.to_param, task_name: 'restart', env: env}
        assert_response :accepted
        assert_json 'type', 'task'
        assert_json 'status', 'pending'
      end

      test "#trigger returns a 404 when the task doesn't exist" do
        post :trigger, params: {stack_id: @stack.to_param, task_name: 'doesnt_exist'}
        assert_response :not_found
      end
    end
  end
end
