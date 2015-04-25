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
    branches = params[:branches] || []
    if branches.find { |branch| branch[:name] == stack.branch }
      commit = stack.commits.find_by_sha!(params[:sha])
      commit.statuses.create!(params.permit(:state, :description, :target_url, :context, :created_at))
    end
    head :ok
  end

  params do
    requires :team do
      requires :id, Integer
      requires :name, String
      requires :slug, String
      requires :url, String
    end
    requires :organization do
      requires :login, String
    end
    requires :member do
      requires :login, String
    end
  end
  def membership
    team = find_or_create_team!
    member = User.find_or_create_by_login!(params.member.login)

    case membership_action
    when 'added'
      team.add_member(member)
    when 'removed'
      team.members.delete(member)
    else
      raise ArgumentError, "Don't know how to perform action: `#{params.action.inspect}`"
    end
    head :ok
  end

  def index
    render text: "working"
  end

  private

  def find_or_create_team!
    Team.find_or_create_by!(github_id: params.team.id) do |team|
      team.github_team = params.team
      team.organization = params.organization.login
      team.automatically_setup_hooks = true
    end
  end

  def verify_signature
    request.body.rewind
    head(422) unless webhook.verify_signature(request.headers['X-Hub-Signature'], request.body.read)
  end

  def check_if_ping
    head :ok if event == 'ping'
  end

  def webhook
    @webhook ||= if params[:stack_id]
      stack.github_hooks.find_by!(event: event)
    else
      GithubHook::Organization.find_by!(organization: params.organization.login, event: event)
    end
  end

  def event
    request.headers['X-Github-Event'] || action_name
  end

  def membership_action
    # GitHub send an `action` parameter that is shadowed by Rails url parameters
    # It's also impossible to pass an `action` parameters from a test case.
    request.request_parameters['action'] || params[:_action]
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end
end
