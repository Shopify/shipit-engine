# frozen_string_literal: true
module Shipit
  class Status
    module Common
      def unknown?
        state == 'unknown'
      end

      def pending?
        state == 'pending'
      end

      def success?
        state == 'success'
      end

      def error?
        state == 'error'
      end

      def failure?
        state == 'failure'
      end

      def missing?
        false
      end

      def group?
        false
      end

      def simple_state
        state == 'error' ? 'failure' : state
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
