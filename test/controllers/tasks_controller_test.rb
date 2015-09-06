require 'test_helper'

class TasksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
    @definition = @stack.find_task_definition('restart')
    @task = tasks(:shipit_restart)
    @commit = commits(:second)
    session[:user_id] = users(:walrus).id
  end

  test "tasks defined in the shipit.yml can be displayed" do
    get :new, stack_id: @stack, definition_id: @definition.id
    assert_response :ok
  end

  test "tasks defined in the shipit.yml can be triggered" do
    assert_difference '@stack.tasks.count', 1 do
      post :create, stack_id: @stack, definition_id: @definition.id
    end
    assert_redirected_to stack_task_path(@stack, Task.last)
  end

  test "triggered tasks can be observed" do
    get :show, stack_id: @stack, id: @task.id
    assert_response :ok
  end

  test ":abort call abort! on the deploy" do
    @task = deploys(:shipit_running)
    @task.pid = 42
    post :abort, stack_id: @stack.to_param, id: @task.id

    @task.reload
    assert_response :success
    assert_equal 'aborting', @task.reload.status
    assert_equal false, @task.rollback_once_aborted?
  end

  test ":abort schedule the rollback if `rollback` is present" do
    @task = deploys(:shipit_running)
    @task.pid = 42
    post :abort, stack_id: @stack.to_param, id: @task.id, rollback: 'true'

    @task.reload
    assert_response :success
    assert_equal 'aborting', @task.status
    assert_equal true, @task.rollback_once_aborted?
  end

  test ":index list the stack deploys" do
    get :index, stack_id: @stack.to_param
    assert_response :success
    assert_select '.task-list .task', @stack.tasks.count
  end

  test ":index paginates with the `since` parameter" do
    get :index, stack_id: @stack.to_param, since: @stack.tasks.last.id
    assert_response :success
    assert_select '.task-list .task', @stack.tasks.count - 1
  end

  test ":tail returns the task status, output, and next url" do
    @task = deploys(:shipit_running)
    last_chunk = @task.chunks.last

    get :tail, stack_id: @stack.to_param, id: @task.id, last_id: last_chunk.id, format: :json
    assert_response :success
    assert_json_keys %w(url status output)
    assert_json 'status', @task.status
  end

  test ":tail doesn't returns the next url if the task is finished" do
    @task = deploys(:shipit)

    get :tail, stack_id: @stack.to_param, id: @task.id, format: :json
    assert_response :success
    assert_no_json 'url'
  end

  test ":tail returns the rollback url if the task have been aborted" do
    @task = deploys(:shipit_aborted)

    get :tail, stack_id: @stack.to_param, id: @task.id, format: :json
    assert_response :success
    assert_json_keys %w(status output rollback_url)
  end
end
