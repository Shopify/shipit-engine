# frozen_string_literal: true

module Shipit
  module Api
    class LocksController < BaseController
      require_permission :lock, :stack

      params do
        requires :reason, String, presence: true
      end
      def create
        if stack.locked?
          render(json: { message: 'Already locked' }, status: :conflict)
        else
          stack.lock(params.reason, current_user)
          render_resource(stack)
        end
      end

      params do
        requires :reason, String, presence: true
      end
      def update
        stack.lock(params.reason, current_user)
        render_resource(stack)
      end

      def destroy
        if (found_stack = stacks.from_param(params[:stack_id]))
          found_stack.unlock
          render_resource(found_stack)
        else
          head(:no_content)
        end
      end
    end
  end
end
