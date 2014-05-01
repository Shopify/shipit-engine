class DeploysController < ApplicationController
  include ChunksHelper

  before_action :load_stack
  before_action :load_deploy, only: :show
  before_action :load_until_commit, only: :create

  def new
    @commit = @stack.commits.where(:sha => params[:sha]).first!
    @deploy = @stack.deploys.new(:until_commit => @commit)
  end

  def show
    respond_with(@deploy) do |format|
      format.html.partial {
        render partial: "deploys/deploy", locals: { deploy: @deploy }
      }
    end
  end

  def create
    @deploy = @stack.trigger_deploy(@until_commit, user_info)
    respond_with(@deploy.stack, @deploy)
  end

  private

  def user_info
    session_user = session[:user] || {}
    {
      user_email: session_user[:email] || 'anonymous@example.com',
      user_name: session_user[:name] || 'Anonymous',
      user: session_user[:email] && User.find_by_email(session[:email])
    }
  end

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
