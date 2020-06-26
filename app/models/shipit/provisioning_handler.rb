# frozen_string_literal: true

module Shipit
  module ProvisioningHandler
    class << self
      def handlers
        @handlers ||= reset!
      end

      def reset!
        @handlers = {}
      end

      def register(github_repo_name, callable)
        handlers[github_repo_name] = callable if callable.present?
      end

      def for_stack(stack)
        handlers[stack.github_repo_name] || handlers[:default] || ProvisioningHandler::Base
      end
    end
  end
end
