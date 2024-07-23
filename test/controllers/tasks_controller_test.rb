# frozen_string_literal: true
require 'test_helper'

module Shipit
  class TasksControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @definition = @stack.find_task_definition('restart')
      @task = shipit_tasks(:shipit_restart)
      @commit = shipit_commits(:second)
      session[:user_id] = shipit_users(:walrus).id
    end

    test "tasks defined in the shipit.yml can be displayed with default variable values" do
      get :new, params: { stack_id: @stack, definition_id: @definition.id }
      assert_response :ok
      assert_select 'input[name="task[env][FOO]"][value="1"]'
    end

    test "it is possible to provide a default value override for a task" do
      get :new, params: { stack_id: @stack, definition_id: @definition.id, FOO: '42' }
      assert_response :ok
      assert_select 'input[name="task[env][FOO]"][value="42"]'
    end

    test "tasks defined in the shipit.yml can't be triggered if the stack is being deployed" do
      shipit_deploys(:shipit_running).update!(allow_concurrency: false, status: 'running')

      assert_predicate @stack, :active_task?
      assert_no_difference -> { @stack.tasks.count } do
        post :create, params: { stack_id: @stack, definition_id: @definition.id }
      end
      assert_redirected_to new_stack_tasks_path(@stack, @definition)
    end

    test "tasks defined in the shipit.yml can be triggered anyway if force param is present" do
      shipit_deploys(:shipit_running).update!(allow_concurrency: false, status: 'running')

      assert_predicate @stack, :active_task?
      assert_difference -> { @stack.tasks.count } do
        post :create, params: { stack_id: @stack, definition_id: @definition.id, force: 'true' }
      end
      assert_redirected_to stack_task_path(@stack, Task.last)
    end

    test "tasks defined in the shipit.yml can be triggered while the stack is being deployed if specified as such" do
      @definition = @stack.find_task_definition('flush_cache')
      assert_difference -> { @stack.tasks.count } do
        post :create, params: { stack_id: @stack, definition_id: @definition.id }
      end
      assert_redirected_to stack_task_path(@stack, Task.last)
    end

    test "tasks with variables defined in the shipit.yml can be triggered with their variables set" do
      env = { "FOO" => "0" }

      post :create, params: { stack_id: @stack, definition_id: @definition.id, task: { env: env }, force: 'true' }

      assert_redirected_to stack_tasks_path(@stack, Task.last)
    end

    test "triggered tasks can be observed" do
      get :show, params: { stack_id: @stack, id: @task.id }
      assert_response :ok
    end

    test "triggered tasks can be observed as raw text" do
      get :show, params: { stack_id: @stack, id: @task.id }, format: 'txt'
      assert_response :success
      assert_equal("text/plain", @response.media_type)
    end

    test ":abort call abort! on the deploy" do
      @task = shipit_deploys(:shipit_running)
      @task.ping
      post :abort, params: { stack_id: @stack.to_param, id: @task.id }

      @task.reload
      assert_response :success
      assert_equal 'aborting', @task.reload.status
      assert_equal shipit_users(:walrus).id, @task.aborted_by_id
      assert_equal false, @task.rollback_once_aborted?
    end

    test ":abort schedule the rollback if `rollback` is present" do
      @task = shipit_deploys(:shipit_running)
      @task.ping
      post :abort, params: { stack_id: @stack.to_param, id: @task.id, rollback: 'true' }

      @task.reload
      assert_response :success
      assert_equal 'aborting', @task.status
      assert_equal shipit_users(:walrus).id, @task.aborted_by_id
      assert_equal true, @task.rollback_once_aborted?
    end

    test ":index list the stack deploys" do
      get :index, params: { stack_id: @stack.to_param }
      assert_response :success
      assert_select '.task-list .task', @stack.tasks.count
    end

    test ":index paginates with the `since` parameter" do
      get :index, params: { stack_id: @stack.to_param, since: @stack.tasks.last.id }
      assert_response :success
      assert_select '.task-list .task', @stack.tasks.count - 1
    end

    test ":tail returns the task status, output, and next url" do
      @task = shipit_deploys(:shipit_running)
      @task.write("dummy output")
      last_chunk = @task.chunk_output.bytesize

      get :tail, params: { stack_id: @stack.to_param, id: @task.id }, format: :json
      assert_response :success
      assert_json_keys %w(url status output)
      assert_json 'status', @task.status
      assert_json 'output', @task.chunk_output
      assert_json 'url', "/shopify/shipit-engine/production/tasks/#{@task.id}/tail?last_byte=#{last_chunk}"
    end

    test ":tail can handle last_byte as string" do
      @task = shipit_deploys(:shipit_running)
      @task.write("dummy output")

      get :tail, params: { stack_id: @stack.to_param, id: @task.id, last_byte: "50" }, format: :json
      assert_response :success
      assert_json_keys %w(url status output)
    end

    test ":tail doesn't returns the next url if the task is finished" do
      @task = shipit_deploys(:shipit)

      get :tail, params: { stack_id: @stack.to_param, id: @task.id }, format: :json
      assert_response :success
      assert_no_json 'url'
    end

    test ":tail returns the rollback url if the task have been aborted" do
      @task = shipit_deploys(:shipit_aborted)

      get :tail, params: { stack_id: @stack.to_param, id: @task.id }, format: :json
      assert_response :success
      assert_json_keys %w(status output rollback_url)
    end

    test ":lookup returns stack task url if the task is an instance of Task" do
      @task = shipit_tasks(:shipit_restart)

      get :lookup, params: { id: @task.id }

      assert_redirected_to stack_task_path(@task.stack, @task)
    end

    test ":lookup returns stack deploy url if the task is an instance of Deploy" do
      @task = shipit_tasks(:shipit)

      get :lookup, params: { id: @task.id }

      assert_redirected_to stack_deploy_path(@task.stack, @task)
    end

    test ":lookup returns stack deploy url if the task is an instance of Rollback" do
      @task = shipit_tasks(:shipit_rollback)

      get :lookup, params: { id: @task.id }

      assert_redirected_to stack_deploy_path(@task.stack, @task)
    end
  end
end
