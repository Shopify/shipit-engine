class TasksController < ShipsterController
  before_action :load_stack

  def new
    @definition = @stack.find_task_definition(params[:definition_id])
    @task = @stack.tasks.build(definition: @definition)
  end

  def show
    @task = @stack.tasks.find(params[:id])
  end

  def create
    @task = @stack.trigger_task(params[:definition_id], current_user)
    redirect_to [@stack, @task]
  end

  private

  def load_stack
    @stack ||= Stack.from_param!(params[:stack_id])
  end
end
