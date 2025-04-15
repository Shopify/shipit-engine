# frozen_string_literal: true

module Shipit
  class Status
    class Group
      include Common

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

        visible_statuses = reject_hidden(statuses.to_a.uniq(&:context))
        missing_contexts = required_statuses - visible_statuses.map(&:context)
        visible_statuses += missing_contexts.map { |c| Status::Missing.new(commit, c) }

        @statuses = visible_statuses.sort_by!(&:context)
      end

      delegate :pending?, :success?, :error?, :failure?, :unknown?, :missing?, :state, :simple_state,
               to: :significant_status
      delegate :each, :size, :map, to: :statuses
      delegate :required_statuses, to: :commit

      def to_a
        @statuses.dup
      end

      def description
        "#{success_count} / #{statuses.count} checks OK"
      end

      def target_url; end

      def to_partial_path
        'statuses/group'
      end

      def group?
        true
      end

      def blocking?
        statuses.any?(&:blocking?)
      end

      private

      def reject_hidden(statuses)
        statuses.reject(&:hidden?)
      end

      def reject_allowed_to_fail(statuses)
        statuses.reject(&:allowed_to_fail?)
      end

      def significant_status
        @significant_status ||= select_significant_status(statuses)
      end

      def select_significant_status(statuses)
        statuses = reject_allowed_to_fail(statuses)
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
