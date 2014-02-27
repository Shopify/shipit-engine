class WebhooksController < ApplicationController
  skip_before_filter :verify_authenticity_token

  respond_to :json

  def push
    branch = payload['ref'].gsub('refs/heads/', '')
    GitRefreshJob.perform_async(stack.id) if branch == stack.branch
    head :ok
  end

  def index
    render text: "working"
  end

  private

  def payload
    JSON.load(params[:payload])
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end
end
