# frozen_string_literal: true

module Shipit
  class Status
    class Missing
      include Common

      attr_reader :commit, :context

      def initialize(commit, context)
        @commit = commit
        @context = context
      end

      def target_url
        nil
      end

      def state
        'pending'
      end

      def missing?
        true
      end

      def description
        I18n.t('missing_status.description', context: context)
      end

      def to_partial_path
        'shipit/statuses/status'
      end
    end
  end
end
