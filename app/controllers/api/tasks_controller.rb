module Api
  class TasksController < BaseController
    before_action :load_stack

    def index
      render_resources @stack.tasks
    end

    def show
      render json: @stack.tasks.find(params[:id])
    end

    private

    def load_stack
      @stack = Stack.from_param(params[:stack_id])
    end
  end
end
