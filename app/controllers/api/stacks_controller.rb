module Api
  class StacksController < BaseController
    def index
      render json: Stack.all
    end
  end
end
