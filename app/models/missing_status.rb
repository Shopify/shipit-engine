class MissingStatus < SimpleDelegator
  def initialize(instance, missing_statuses)
    @missing_statuses = missing_statuses
    super(instance)
  end

  def state
    'missing'
  end

  def success?
    false
  end

  def description
    I18n.t('missing_status.description', missing_statuses: @missing_statuses.to_sentence, count: @missing_statuses.size)
  end
end
