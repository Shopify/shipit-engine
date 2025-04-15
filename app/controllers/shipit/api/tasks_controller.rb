# frozen_string_literal: true

module Shipit
  module Api
    class TasksController < BaseController
      require_permission :read, :stack
      require_permission :deploy, :stack, only: %i[trigger abort]

      def index
        render_resources(stack.tasks)
      end

      def show
        render_resource(task)
      end

      params do
        accepts :env, Hash, default: {}
      end
      def trigger
        render_resource(stack.trigger_task(params[:task_name], current_user, env: params.env), status: :accepted)
      rescue Shipit::Task::ConcurrentTaskRunning
        render(status: :conflict, json: {
                 message: 'A task is already running.'
               })
      end

      def abort
        if task.active?
          task.abort!(aborted_by: current_user)
          head(:accepted)
        else
          render(status: :method_not_allowed, json: {
                   message: "This task is not currently running."
                 })
        end
      end

      private

      def task
        stack.tasks.find(params[:id])
      end
    end
  end
end
