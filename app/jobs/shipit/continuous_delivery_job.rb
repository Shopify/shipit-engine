# frozen_string_literal: true
module Shipit
  class ContinuousDeliveryJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :deploys
    on_duplicate :drop

    def perform(stack)
      return unless stack.continuous_deployment?

      # checks if there are any tasks running, including concurrent tasks
      return if stack.occupied?

      stack.trigger_continuous_delivery
    end
  end
end
