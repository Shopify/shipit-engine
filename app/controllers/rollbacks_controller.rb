class RollbacksController < ApplicationController
  before_action :load_stack
  before_action :load_deploy
  before_action :ensure_stack_is_not_being_deployed

  def create
    @rollback = @deploy.trigger_rollback(current_user)
    redirect_to stack_deploy_path(@stack, @rollback)
  end

  private

  def ensure_stack_is_not_being_deployed
    return unless @stack.deploying?

    redirect_to rollback_stack_deploy_path(@stack, @deploy), error: t('error.deploy_in_progress')
  end

  def load_stack
    @stack ||= Stack.from_param(params[:stack_id])
  end

  def load_deploy
    @deploy = @stack.deploys.find(rollback_params[:parent_id])
  end

  def rollback_params
    params.require(:rollback).permit(:parent_id)
  end
end
