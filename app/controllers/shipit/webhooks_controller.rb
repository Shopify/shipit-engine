module Shipit
  class WebhooksController < ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false
    before_action :check_if_ping, :verify_signature

    respond_to :json

    HANDLERS = {
      'push' => PushHandler,
      'status' => StatusHandler,
      'membership' => MembershipHandler,
      'check_suite' => CheckSuiteHandler,
    }.freeze

    def create
      params = JSON.parse(request.raw_post)

      if handler = HANDLERS[event]
        handler.new(params).process
      end

      Shipit::Webhooks.extra_handlers.each do |extra_handler|
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
