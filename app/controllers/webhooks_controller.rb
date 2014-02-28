class WebhooksController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :check_if_ping

  respond_to :json

  def push
    branch = params['ref'].gsub('refs/heads/', '')

    if branch == stack.branch
      Resque.enqueue(GithubSyncJob, stack_id: stack.id)
      Resque.enqueue(GitMirrorUpdateJob, stack_id: stack.id)
    end

    head :ok
  end

  def state
    commit = stack.commits.find_by_sha!(params['sha'])
    commit.update_attributes(state: params['state'])
    head :ok
  end

  def index
    render text: "working"
  end

  private

  def check_if_ping
    return head :ok if request.headers['HTTP_X_GITHUB_EVENT'] == 'ping'
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end
end
