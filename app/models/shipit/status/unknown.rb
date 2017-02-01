module Shipit
  class Status
    class Unknown
      include Common

      attr_reader :commit

      def initialize(commit)
        @commit = commit
      end

      def state
        'unknown'.freeze
      end

      def target_url
        nil
      end

      def description
        ''
      end

      def context
        'ci/unknown'
      end

      def to_partial_path
        'shipit/statuses/status'
      end
    end
  end
end
