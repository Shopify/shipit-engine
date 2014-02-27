class StacksController < ApplicationController
  def index
    @stacks = Stack.all
  end

  def show
    @stack = Stack.find(params[:id])
  end

  def create
    @stack = Stack.create!(create_params)
    respond_with(@stack)
  end

  def destroy
    @stack = Stack.find(params[:id])
    @stack.destroy!
    respond_with(@stack)
  end
  
  private

  def create_params
    params.require(:stack).permit(:repo_name, :repo_owner, :environment, :branch)
  end
end
