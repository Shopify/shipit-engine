# frozen_string_literal: true

module Shipit
  class RollbacksController < ShipitController
    before_action :load_stack
    before_action :load_deploy

    def create
      @rollback = @deploy.trigger_rollback(
        current_user,
        env: rollback_params[:env]&.to_unsafe_hash,
        force: params[:force].present?
      )
      redirect_to(stack_deploy_path(@stack, @rollback))
    rescue Task::ConcurrentTaskRunning
      redirect_to(rollback_stack_deploy_path(@stack, @deploy))
    end

    private

    def load_stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end

    def load_deploy
      @deploy = @stack.deploys.find(rollback_params[:parent_id])
    end

    def rollback_params
      params.require(:rollback).permit(:parent_id, env: @stack.deploy_variables.map(&:name))
    end
  end
end
