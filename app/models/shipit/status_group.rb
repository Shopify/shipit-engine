module Shipit
  class StatusGroup
    STATES_PRIORITY = %w(failure error pending success).freeze

    attr_reader :statuses, :significant_status

    def initialize(significant_status, visible_statuses)
      @significant_status = significant_status
      @statuses = visible_statuses
    end

    delegate :pending?, :success?, :error?, :failure?, :unknown?, :state, to: :significant_status

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

    def success_count
      @statuses.count { |s| s.state == 'success'.freeze }
    end
  end
end
