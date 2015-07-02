require 'test_helper'

class Api::TasksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
    authenticate!
  end

  test "#index returns a list of tasks" do
    task = @stack.tasks.last

    get :index, stack_id: @stack.to_param
    assert_response :ok
    assert_json '0.id', task.id
  end

  test "#show returns a task" do
    task = @stack.tasks.last

    get :show, stack_id: @stack.to_param, id: task.id
    assert_response :ok
    assert_json 'id', task.id
  end

  test "#trigger triggers a custom task" do
    post :trigger, stack_id: @stack.to_param, task_name: 'restart'
    assert_response :accepted
    assert_json 'type', 'task'
    assert_json 'status', 'pending'
  end

  test "#trigger returns a 404 when the task doesn't exist" do
    post :trigger, stack_id: @stack.to_param, task_name: 'doesnt_exist'
    assert_response :not_found
  end
end
