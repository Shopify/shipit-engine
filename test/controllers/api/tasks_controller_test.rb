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
end
