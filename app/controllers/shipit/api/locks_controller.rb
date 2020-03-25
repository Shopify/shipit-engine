# typed: false
module Shipit
  module Api
    class LocksController < BaseController
      require_permission :lock, :stack

      params do
        requires :reason, String, presence: true
      end
      def create
        if stack.locked?
          render json: {message: 'Already locked'}, status: :conflict
        else
          stack.lock(params.reason, current_user)
          render_resource stack
        end
      end

      params do
        requires :reason, String, presence: true
      end
      def update
        stack.lock(params.reason, current_user)
        render_resource stack
      end

      def destroy
        stack.unlock
        render_resource stack
      end
    end
  end
end
