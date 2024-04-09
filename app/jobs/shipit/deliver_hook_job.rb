# frozen_string_literal: true

module Shipit
  class DeliverHookJob < BackgroundJob
    queue_as :hooks

    def perform(delivery)
      delivery = Hook::DeliverySpec.new(**delivery) if delivery.is_a?(Hash)
      delivery.send!
    end
  end
end
