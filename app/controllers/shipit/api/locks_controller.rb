module Shipit
  module Api
    class LocksController < BaseController
      require_permission :lock, :stack

      params do
        requires :reason, String, presence: true
        accepts :lock_level, String

        validates :lock_level, inclusion: { in: Shipit::Stack::LOCK_LEVELS }
      end
      def create
        if stack.locked?
          render json: {message: 'Already locked'}, status: :conflict
        else
          stack.lock(params.reason, current_user, lock_level: params.lock_level)
          render_resource stack
        end
      end

      params do
        requires :reason, String, presence: true
        accepts :lock_level, String

        validates :lock_level, inclusion: { in: Shipit::Stack::LOCK_LEVELS }
      end
      def update
        stack.lock(params.reason, current_user, lock_level: params.lock_level)
        render_resource stack
      end

      def destroy
        stack.unlock
        render_resource stack
      end
    end
  end
end
