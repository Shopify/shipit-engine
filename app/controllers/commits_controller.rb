class CommitsController < ApplicationController
  def show
    @stack = Stack.from_param(params[:stack_id])
    @commit = @stack.commits.find(params[:id])
    respond_to do |format|
      format.partial {
        render partial: "commits/commit", locals: { commit: @commit }, formats: [:html]
      }
    end
  end
end
