module Api
  class OutputsController < BaseController
    def show
      render plain: task.chunk_output
    end

    private

    def task
      @task ||= stack.tasks.find(params[:task_id])
    end

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
