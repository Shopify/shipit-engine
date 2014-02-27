class StacksController < ApplicationController
  def new
    @stack = Stack.new
  end

  def index
    @stacks = Stack.all
  end

  def show
    @stack = Stack.from_param(params[:id])
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
