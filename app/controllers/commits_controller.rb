class CommitsController < ApplicationController
  def show
    @stack = Stack.from_param(params[:stack_id])
    @commit = @stack.commits.find(params[:id])
    render partial: "commits/list_item", locals: { commit: @commit }
  end
end
