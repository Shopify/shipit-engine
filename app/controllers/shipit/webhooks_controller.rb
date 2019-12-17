module Shipit
  class WebhooksController < ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false
    before_action :check_if_ping, :verify_signature

    respond_to :json

    class Handler
      class << self
        attr_reader :param_parser

        def params(&block)
          @param_parser = ExplicitParameters::Parameters.define(&block)
        end
      end

      attr_reader :params, :payload

      def initialize(payload)
        @payload = payload
        @params = self.class.param_parser.parse!(payload)
      end

      def process
        raise NotImplementedError
      end

      private

      def stacks
        @stacks ||= Repository.from_github_repo_name(repository_name).stacks
      end

      def repository_name
        payload.dig('repository', 'full_name')
      end
    end

    class PushHandler < Handler
      params do
        requires :ref
      end
      def process
        stacks.where(branch: branch).each(&:sync_github)
      end

      private

      def branch
        params.ref.gsub('refs/heads/', '')
      end
    end

    class StatusHandler < Handler
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
      def process
        Commit.where(sha: params.sha).each do |commit|
          commit.create_status_from_github!(params)
        end
      end
    end

    class CheckSuiteHandler < Handler
      params do
        requires :check_suite do
          requires :head_sha, String
          requires :head_branch, String
        end
      end
      def process
        stacks.where(branch: params.check_suite.head_branch).each do |stack|
          stack.commits.where(sha: params.check_suite.head_sha).each(&:schedule_refresh_check_runs!)
        end
      end
    end

    class MembershipHandler < Handler
      params do
        requires :action, String
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
      def process
        team = find_or_create_team!
        member = User.find_or_create_by_login!(params.member.login)

        case params.action
        when 'added'
          team.add_member(member)
        when 'removed'
          team.members.delete(member)
        else
          raise ArgumentError, "Don't know how to perform action: `#{action.inspect}`"
        end
      end

      private

      def find_or_create_team!
        Team.find_or_create_by!(github_id: params.team.id) do |team|
          team.github_team = params.team
          team.organization = params.organization.login
        end
      end
    end

    HANDLERS = {
      'push' => PushHandler,
      'status' => StatusHandler,
      'membership' => MembershipHandler,
      'check_suite' => CheckSuiteHandler,
    }.freeze

    class << self
      attr_accessor :extra_handlers
    end

    self.extra_handlers = []

    def self.register_handler(&block)
      extra_handlers << block
    end

    def create
      params = JSON.parse(request.raw_post)

      if handler = HANDLERS[event]
        handler.new(params).process
      end

      self.class.extra_handlers.each do |extra_handler|
        extra_handler.call(event, params)
      end

      head :ok
    end

    private

    def verify_signature
      head(422) unless Shipit.github.verify_webhook_signature(request.headers['X-Hub-Signature'], request.raw_post)
    end

    def check_if_ping
      head :ok if event == 'ping'
    end

    def event
      request.headers.fetch('X-Github-Event')
    end

    def stack
      @stack ||= Stack.find(params[:stack_id])
    end
  end
end
