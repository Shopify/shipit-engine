module Api
  class StacksController < BaseController
    require_permission :read, :stack

    def index
      render_resources stacks
    end

    def show
      render_resource stack
    end
  end
end
