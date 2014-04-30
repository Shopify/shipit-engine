class CommitsController < ApplicationController
  def show
    @stack = Stack.from_param(params[:stack_id])
    @commit = @stack.commits.find(params[:id])

    respond_to do |format|
      format.html.partial {
        render partial: "commits/commit", locals: { commit: @commit }
      }
    end
  end
end
