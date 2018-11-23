module Shipit
  class ReleaseStatusesController < ShipitController
    before_action :load_stack
    before_action :load_deploy

    def create
      case params[:status]
      when 'success'
        @deploy.report_healthy!(user: current_user)
      when 'failure'
        @deploy.report_faulty!(user: current_user)
      else
        render status: :unprocessable_entity, json: {message: "Invalid `status` parameter"}
      end
      render status: :created, json: @deploy.last_release_status
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
