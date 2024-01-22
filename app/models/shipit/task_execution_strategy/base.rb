# frozen_string_literal: true

module Shipit
  module TaskExecutionStrategy
    class Base
      def initialize(task)
        self.task = task
      end

      def execute
        raise(
          NotImplmentedError,
          "subclasses of TaskExectuionStrategy::Base must implement the #execute method",
        )
      end

      attr_accessor :task
    end
  end
end
