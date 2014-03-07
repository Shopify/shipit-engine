class WebhooksController < ActionController::Base
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
    attributes = {
      state: params['state']
    }
    attributes.merge!(target_url: params['target_url']) if params['target_url'].present?
    commit.update_attributes(attributes)
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
