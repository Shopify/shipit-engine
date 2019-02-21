module Shipit
  module Api
    class ReleaseStatusesController < BaseController
      require_permission :deploy, :stack

      params do
        requires :status, String
      end
      def create
        deploy = stack.deploys_and_rollbacks.find(params[:deploy_id])
        case params[:status]
        when 'success'
          deploy.report_healthy!(user: current_user)
        when 'failure'
          deploy.report_faulty!(user: current_user)
        else
          param_error!(:status, 'Invalid status')
        end
        render_resource deploy, status: :created
      end
    end
  end
end
