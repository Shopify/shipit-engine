module Shipit
  class Status
    class Unknown
      include GlobalID::Identification
      include Common

      class << self
        def find(id)
          new(Commit.find(id))
        end
      end

      attr_reader :commit

      def initialize(commit)
        @commit = commit
      end

      def id
        commit.id
      end

      def state
        'unknown'.freeze
      end

      def missing?
        true
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
