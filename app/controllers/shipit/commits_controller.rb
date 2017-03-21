module Shipit
  class CommitsController < ShipitController
    def update
      commit.update(params.require(:commit).permit(:locked))
      head :ok
    end

    private

    def commit
      @commit ||= stack.commits.find(params[:id])
    end

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
