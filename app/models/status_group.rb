class StatusGroup
  STATES_PRIORITY = %w(failure error pending success).freeze

  attr_reader :statuses, :significant_status

  def initialize(commit)
    @significant_status = commit.significant_status
    @statuses = commit.visible_statuses
  end

  delegate :state, to: :significant_status

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
