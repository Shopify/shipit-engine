module Shipit
  class WebhooksController < ActionController::Base
    before_action :check_if_ping, :verify_signature

    respond_to :json

    def push
      branch = params['ref'].gsub('refs/heads/', '')

      if branch == stack.branch
        GithubSyncJob.perform_later(stack_id: stack.id)
      end

      head :ok
    end

    params do
      requires :sha, String
      requires :state, String
      accepts :description, String
      accepts :target_url, String
      accepts :context, String
      accepts :created_at, String

      accepts :branches, Array do
        requires :name, String
      end
    end
    def state
      if commit = stack.commits.find_by_sha(params.sha)
        commit.create_status_from_github!(params)
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
      head(422) unless webhook.verify_signature(request.headers['X-Hub-Signature'], request.raw_post)
    end

    def check_if_ping
      head :ok if event == 'ping'
    end

    def webhook
      @webhook ||= if params[:stack_id]
        stack.github_hooks.find_by!(event: event)
      else
        GithubHook::Organization.find_by!(organization: params.organization.login.downcase, event: event)
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
end
