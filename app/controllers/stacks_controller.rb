class StacksController < ApplicationController
  def new
    @stack = Stack.new
  end

  def index
    @stacks = Stack.all
  end

  def show
    @stack   = Stack.preload(:commits => :author).from_param(params[:id])
    @deploys = @stack.deploys.order(id: :desc).preload(:since_commit, :until_commit).limit(10)
    @commits = @stack.commits.order(id: :desc).preload(:author)
    if deployed_commit_id = @stack.deploys.last.try(:until_commit_id)
      @commits = @commits.where('id > ?', deployed_commit_id)
    end
  end

  def create
    @stack = Stack.create!(create_params)
    respond_with(@stack)
  end

  def destroy
    @stack = Stack.from_param(params[:id])
    @stack.destroy!
    respond_with(@stack)
  end

  def settings
    @stack = Stack.from_param(params[:id])
  end

  private

  def create_params
    params.require(:stack).permit(:repo_name, :repo_owner, :environment, :branch)
  end
end
