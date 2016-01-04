module Shipit
  class DeliverHookJob < BackgroundJob
    queue_as :hooks

    def perform(delivery)
      delivery.send!
    end
  end
end
