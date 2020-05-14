# frozen_string_literal: true
module Shipit
  module Api
    class ReleaseStatusesController < BaseController
      require_permission :deploy, :stack

      params do
        requires :status, String
        validates :status, inclusion: { in: %w(success failure) }
      end
      def create
        deploy = stack.deploys_and_rollbacks.find(params[:deploy_id])
        case params[:status]
        when 'success'
          deploy.report_healthy!(user: current_user)
        when 'failure'
          deploy.report_faulty!(user: current_user)
        end
        render_resource(deploy, status: :created)
      end
    end
  end
end
