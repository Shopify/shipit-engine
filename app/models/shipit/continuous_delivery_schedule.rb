# frozen_string_literal: true

module Shipit
  class ContinuousDeliverySchedule < Record
    belongs_to(:stack)

    DAYS = %w[sunday monday tuesday wednesday thursday friday saturday]
  end
end
