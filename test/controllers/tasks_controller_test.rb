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
    assert_difference '@stack.tasks.count', +1 do
      post :create, stack_id: @stack, definition_id: @definition.id
    end
    assert_redirected_to stack_task_path(@stack, Task.last)
  end

  test "triggered tasks can be observed" do
    get :show, stack_id: @stack, id: @task.id
    assert_response :ok
  end

  test ":abort call abort! on the deploy" do
    Task.any_instance.expects(:abort!)
    post :abort, stack_id: @stack.to_param, id: @task.id
    assert_response :success
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
end
