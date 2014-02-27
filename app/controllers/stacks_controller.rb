class StacksController < ApplicationController
  def index
    @stacks = Stack.all
  end

  def show
    @stack = Stack.find(params[:id])
  end
end
