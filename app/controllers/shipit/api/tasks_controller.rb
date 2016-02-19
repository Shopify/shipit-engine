module Shipit
  module Api
    class TasksController < BaseController
      require_permission :read, :stack
      require_permission :deploy, :stack, only: :trigger

      def index
        render_resources stack.tasks
      end

      def show
        render_resource stack.tasks.find(params[:id])
      end

      params do
        accepts :env, Hash, default: {}
      end
      def trigger
        render_resource stack.trigger_task(params[:task_name], current_user, env: params.env), status: :accepted
      end
    end
  end
end
