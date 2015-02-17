module Api
  class StacksController < BaseController
    def index
      render_resources Stack.all
    end

    def show
      render json: Stack.from_param!(params[:id])
    end
  end
end
