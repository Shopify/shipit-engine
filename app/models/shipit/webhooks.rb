# frozen_string_literal: true

module Shipit
  module Webhooks
    class << self
      def default_handlers
        {
          'push' => [Handlers::PushHandler],
          'pull_request' => [
            Handlers::PullRequest::OpenedHandler,
            Handlers::PullRequest::ClosedHandler,
            Handlers::PullRequest::ReopenedHandler,
            Handlers::PullRequest::EditedHandler,
            Handlers::PullRequest::AssignedHandler,
            Handlers::PullRequest::LabeledHandler,
            Handlers::PullRequest::UnlabeledHandler,
            Handlers::PullRequest::LabelCapturingHandler,
          ],
          'status' => [Handlers::StatusHandler],
          'membership' => [Handlers::MembershipHandler],
          'check_suite' => [Handlers::CheckSuiteHandler],
        }
      end

      def handlers
        @handlers ||= reset_handlers!
      end

      def reset_handlers!
        @handlers = default_handlers
      end

      def register_handler(event, callable = nil, &block)
        handlers[event] ||= []
        handlers[event] << callable if callable
        handlers[event] << block if block_given?
      end

      def for_event(event)
        handlers.fetch(event) { [] }
      end
    end
  end
end
