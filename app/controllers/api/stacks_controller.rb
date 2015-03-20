module Api
  class StacksController < BaseController
    def index
      render_resources Stack.all
    end

    def show
      render_resource stack
    end

    private

    def stack
      @stack ||= Stack.from_param!(params[:id])
    end
  end
end
