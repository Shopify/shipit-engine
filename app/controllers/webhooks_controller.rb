class WebhooksController < ApplicationController
  skip_before_filter :verify_authenticity_token

  respond_to :json

  def push
    branch = payload['ref'].gsub('refs/heads/', '')

    if branch == stack.branch
      Resque.enqueue(GithubSyncJob, stack_id: stack.id)
      Resque.enqueue(GitMirrorUpdateJob, stack_id: stack.id)
    end

    head :ok
  end

  def state
    commit = stack.commits.find_by_sha!(payload['sha'])
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
    @stack ||= Stack.from_param(params[:stack_id])
  end
end
