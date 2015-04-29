class DeploysController < ApplicationController
  include ChunksHelper

  before_action :load_stack
  before_action :load_deploy, only: %i(show rollback abort)
  before_action :load_until_commit, only: :create

  def new
    @commit = @stack.commits.by_sha!(params[:sha])
    @deploy = @stack.deploys.new(until_commit: @commit, since_commit: @stack.last_deployed_commit)
  end

  def show
  end

  def create
    return redirect_to new_stack_deploy_path(@stack, sha: @until_commit.sha) if !params[:force] && @stack.deploying?
    @deploy = @stack.trigger_deploy(@until_commit, current_user)
    respond_with(@deploy.stack, @deploy)
  end

  def rollback
    @rollback = @deploy.build_rollback
  end

  def abort
    @deploy.abort!
    head :ok
  end

  private

  def load_deploy
    @deploy = @stack.deploys.find(params[:id])
  end

  def load_stack
    @stack ||= Stack.from_param!(params[:stack_id])
  end

  def load_until_commit
    @until_commit = @stack.commits.find(deploy_params[:until_commit_id])
  end

  def deploy_params
    @deploy_params ||= params.require(:deploy).permit(:until_commit_id)
  end
end
