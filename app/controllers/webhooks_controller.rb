class WebhooksController < ApplicationController
  skip_before_filter :verify_authenticity_token

  respond_to :json

  def push
    branch = payload['ref'].gsub('refs/heads/', '')
    Resque.enqueue(GitRefreshJob, stack.id) if branch == stack.branch
    head :ok
  end

  def state
    commit = Commit.find_by_sha!(payload['sha'])
    commit.update_attributes(state: payload['state'])
    head :ok
  end

  def index
    render text: "working"
  end

  private

  def payload
    @payload ||= JSON.load(params[:payload])
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end
end
