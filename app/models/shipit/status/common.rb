module Shipit
  class Status
    module Common
      def unknown?
        state == 'unknown'.freeze
      end

      def pending?
        state == 'pending'.freeze
      end

      def success?
        state == 'success'.freeze
      end

      def error?
        state == 'error'.freeze
      end

      def failure?
        state == 'failure'.freeze
      end

      def group?
        false
      end

      def simple_state
        state == 'error'.freeze ? 'failure'.freeze : state
      end

      def allowed_to_fail?
        commit.soft_failing_statuses.include?(context)
      end

      def hidden?
        commit.hidden_statuses.include?(context)
      end

      def blocking?
        !success? && commit.blocking_statuses.include?(context)
      end

      def required?
        commit.required_statuses.include?(context)
      end
    end
  end
end
