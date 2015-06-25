class StatusGroup
  STATES_PRIORITY = %w(failure error pending success).freeze

  attr_reader :statuses

  def initialize(statuses)
    @statuses = statuses
  end

  delegate :state, to: :main_status

  def description
    "#{success_count} / #{@statuses.count} checks OK"
  end

  def target_url
  end

  def main_status
    @main_status ||= find_main_status
  end

  def to_partial_path
    'statuses/group'
  end

  def group?
    true
  end

  private

  def find_main_status
    STATES_PRIORITY.each do |state|
      status = @statuses.find { |s| s.state == state }
      return status if status
    end
    fail "No status found, this is not supposed to happen"
  end

  def success_count
    @statuses.count { |s| s.state == 'success'.freeze }
  end
end
