module Api
  class TasksController < BaseController
    def index
      render_resources stack.tasks
    end

    def show
      render_resource stack.tasks.find(params[:id])
    end
  end
end
