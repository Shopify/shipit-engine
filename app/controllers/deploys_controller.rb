class DeploysController < ApplicationController
  include ChunksHelper

  before_action :load_stack
  before_action :load_deploy, only: :show
  before_action :load_until_commit, only: :create

  def new
    if params[:deploy_id]
      @deploy = @stack.deploys.find(params[:deploy_id]).dup
      @deploy.parent_id = params[:deploy_id]
      @deploy.rollback = true
    else
      @commit = @stack.commits.where(sha: params[:sha]).first!
      @deploy = stack.deploys.new(until_commit: @commit, since_commit: @stack.last_deployed_commit)
    end
  end

  def show
    respond_with(@deploy) do |format|
      format.html.partial {
        render partial: "deploys/deploy", locals: { deploy: @deploy }
      }
    end
  end

  def create
    @deploy = @stack.trigger_deploy(@until_commit, current_user)
    respond_with(@deploy.stack, @deploy)
  end

  private

  def load_deploy
    @deploy = @stack.deploys.find(params[:id])
  end

  def load_stack
    @stack ||= Stack.from_param(params[:stack_id])
  end

  def load_until_commit
    @until_commit = @stack.commits.find(deploy_params[:until_commit_id])
  end

  def deploy_params
    @deploy_params ||= params.require(:deploy).permit(:until_commit_id)
  end

end
