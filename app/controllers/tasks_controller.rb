class TasksController < ShipitController
  before_action :stack

  def new
    @definition = stack.find_task_definition(params[:definition_id])
    @task = stack.tasks.build(definition: @definition)
  end

  def show
    task
  end

  def create
    @task = stack.trigger_task(params[:definition_id], current_user)
    redirect_to [stack, @task]
  end

  def abort
    task.abort!
    head :ok
  end

  private

  def task
    @task ||= stack.tasks.find(params[:id])
  end

  def stack
    @stack ||= Stack.from_param!(params[:stack_id])
  end
end
