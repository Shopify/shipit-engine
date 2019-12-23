require 'shipit/webhooks/handlers'

module Shipit
  module Webhooks
    def self.default_handlers
      {
        'push' => [Handlers::PushHandler],
        'status' => [Handlers::StatusHandler],
        'membership' => [Handlers::MembershipHandler],
        'check_suite' => [Handlers::CheckSuiteHandler],
      }
    end

    def self.handlers
      @handlers ||= reset_handler_registry
    end

    def self.reset_handler_registry
      @handlers = default_handlers
    end

    def self.register_handler(event, callable = nil, &block)
      handlers[event] ||= []
      handlers[event] << callable if callable
      handlers[event] << block if block_given?
    end

    def self.for_event(event)
      handlers.fetch(event) { [] }
    end
  end
end
