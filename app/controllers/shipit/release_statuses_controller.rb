module Shipit
  class ReleaseStatusesController < ShipitController
    before_action :load_stack
    before_action :load_deploy

    def create
      case params[:status]
      when 'success'
        @deploy.append_release_status(
          'success',
          "@#{current_user.login} signaled this release as healthy.",
          user: current_user,
        )
      when 'failure'
        @deploy.append_release_status(
          'failure',
          "@#{current_user.login} signaled this release as faulty.",
          user: current_user,
        )
      else
        render status: :unprocessable_entity, json: {message: "Invalid `status` parameter"}
      end
      render json: @deploy.last_release_status
    end

    private

    def load_deploy
      @deploy = @stack.deploys_and_rollbacks.find(params[:deploy_id])
    end

    def load_stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
