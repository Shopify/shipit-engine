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
          stack.update(lock_reason: params.reason, lock_author: current_user)
          render_resource stack
        end
      end

      params do
        requires :reason, String, presence: true
      end
      def update
        stack.update(lock_reason: params.reason, lock_author: current_user)
        render_resource stack
      end

      def destroy
        stack.update(lock_reason: nil, lock_author: nil)
        render_resource stack
      end
    end
  end
end
