# typed: false
module Shipit
  class WebhooksController < ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false
    before_action :check_if_ping, :verify_signature

    respond_to :json

    def create
      params = JSON.parse(request.raw_post)
      Shipit::Webhooks.for_event(event).each { |handler| handler.call(params) }

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
