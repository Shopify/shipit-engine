class WebhooksController < ActionController::Base
  before_action :check_if_ping, :verify_signature

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
    commit = stack.commits.find_by_sha!(params[:sha])
    commit.statuses.create!(params.permit(:state, :description, :target_url, :context, :created_at))
    head :ok
  end

  def index
    render text: "working"
  end

  private

  def verify_signature
    request.body.rewind
    head(422) unless webhook.verify_signature(request.headers['X-Hub-Signature'], request.body.read)
  end

  def check_if_ping
    head :ok if event == 'ping'
  end

  def webhook
    @webhook ||= stack.webhooks.where(event: event).first!
  end

  def event
    request.headers['X-Github-Event']
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end
end
