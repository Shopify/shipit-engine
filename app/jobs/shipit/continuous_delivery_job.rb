module Shipit
  class ContinuousDeliveryJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    def perform(stack)
      stack.trigger_continuous_deploy
    end
  end
end
