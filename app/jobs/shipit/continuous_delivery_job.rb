module Shipit
  class ContinuousDeliveryJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    def perform(stack)
      return unless stack.continuous_deployment?
      stack.trigger_continuous_delivery
    end
  end
end
