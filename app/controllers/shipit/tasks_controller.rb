module Shipit
  class TasksController < ShipitController
    include Pagination

    before_action :stack

    self.default_page_size = 20

    def index
      paginator = paginate(stack.tasks)
      @tasks = paginator.to_a
      @links = paginator.links
    end

    def new
      @definition = stack.find_task_definition(params[:definition_id])
      @task = stack.tasks.build(definition: @definition)
    end

    def show
      task
      respond_to do |format|
        format.html
        format.text { render plain: @task.chunk_output }
      end
    end

    def create
      @definition = stack.find_task_definition(params[:definition_id])

      begin
        @task = stack.trigger_task(
          params[:definition_id],
          current_user,
          env: task_params[:env],
          force: params[:force].present?,
        )
        redirect_to [stack, @task]
      rescue Task::ConcurrentTaskRunning
        redirect_to new_stack_tasks_path(stack, @definition)
      end
    end

    def abort
      task.abort!(rollback_once_aborted: params[:rollback].present?)
      head :ok
    end

    def tail
      render json: TailTaskSerializer.new(task, context: params)
    end

    private

    def task
      @task ||= stack.tasks.find(params[:id])
    end

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end

    def task_params
      return {} unless params[:task]
      @definition = stack.find_task_definition(params[:definition_id])
      @task_params ||= params.require(:task).permit(env: @definition.variables.map(&:name))
    end
  end
end
