# frozen_string_literal: true

module Shipit
  module TaskExecutionStrategy
    class << self
      def registry
        @registry ||= reset_registry!
      end

      def reset_registry!
        @registry = {}
      end

      def register(task_type, strategy)
        registry[task_type.name] = strategy
      end

      def for(task)
        strategy = registry.fetch(task.class.name) { default }

        strategy.new(task)
      end

      DEFAULT_REGISTRY_KEY = :default
      def default=(strategy)
        registry[DEFAULT_REGISTRY_KEY] = strategy
      end

      def default
        registry.fetch(DEFAULT_REGISTRY_KEY) { Shipit::TaskExecutionStrategy::Default }
      end
    end
  end
end
