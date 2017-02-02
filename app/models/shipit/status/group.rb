module Shipit
  class Status
    class Group
      attr_reader :commit, :statuses

      class << self
        def compact(commit, statuses)
          group = new(commit, statuses)
          case group.size
          when 0
            Status::Unknown.new(commit)
          when 1
            group.statuses.first
          else
            group
          end
        end
      end

      def initialize(commit, statuses)
        @commit = commit

        visible_statuses = statuses.to_a.uniq(&:context).reject(&:hidden?)
        missing_contexts = commit.required_statuses - visible_statuses.map(&:context)
        visible_statuses += missing_contexts.map { |c| Status::Missing.new(commit, c) }

        @statuses = visible_statuses.sort_by!(&:context)
      end

      delegate :pending?, :success?, :error?, :failure?, :unknown?, :state, :simple_state, to: :significant_status
      delegate :each, :size, :map, to: :statuses

      def to_a
        @statuses.dup
      end

      def description
        "#{success_count} / #{statuses.count} checks OK"
      end

      def target_url
      end

      def to_partial_path
        'statuses/group'
      end

      def group?
        true
      end

      private

      def significant_status
        @significant_status ||= select_significant_status(statuses)
      end

      def select_significant_status(statuses)
        statuses = statuses.reject(&:allowed_to_fail?)
        return Status::Unknown.new(commit) if statuses.empty?
        non_success_statuses = statuses.reject(&:success?)
        return statuses.first if non_success_statuses.empty?
        non_success_statuses.reject(&:pending?).first || non_success_statuses.first || Status::Unknown.new(commit)
      end

      def success_count
        @statuses.count(&:success?)
      end
    end
  end
end
