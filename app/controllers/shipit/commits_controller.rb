# typed: false
module Shipit
  class CommitsController < ShipitController
    def update
      if update_params[:locked].present?
        if Shipit::CastValue.to_boolean(update_params[:locked])
          commit.lock(current_user)
        else
          commit.unlock
        end
      end

      head :ok
    end

    private

    def commit
      @commit ||= stack.commits.find(params[:id])
    end

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end

    def update_params
      @update_params ||= params.require(:commit).permit(:locked)
    end
  end
end
