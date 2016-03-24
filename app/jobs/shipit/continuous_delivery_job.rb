module Shipit
  class ContinuousDeliveryJob < BackgroundJob
    include BackgroundJob::Exclusive

    queue_as :default

    def perform(stack)
      return unless stack.continuous_deployment?
      stack.trigger_continuous_deploy
    end
  end
end
