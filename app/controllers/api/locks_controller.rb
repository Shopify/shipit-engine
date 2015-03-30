module Api
  class LocksController < BaseController
    before_action :load_stack

    params do
      requires :reason, String, presence: true
    end
    def update
      @stack.update(lock_reason: params.reason)
      render_resource @stack
    end

    def destroy
      @stack.update(lock_reason: nil)
      render_resource @stack
    end

    private

    def load_stack
      @stack = Stack.from_param!(params[:stack_id])
    end
  end
end
