module Shipit
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
      statuses = @missing_statuses.to_sentence
      I18n.t('missing_status.description', missing_statuses: statuses, count: @missing_statuses.size)
    end
  end
end
