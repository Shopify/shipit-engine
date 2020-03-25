# typed: false
module Shipit
  module Api
    class OutputsController < BaseController
      require_permission :read, :stack

      def show
        render plain: task.chunk_output
      end

      private

      def task
        @task ||= stack.tasks.find(params[:task_id])
      end
    end
  end
end
