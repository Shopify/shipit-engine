# frozen_string_literal: true

module Shipit
  class EmitEventJob < BackgroundJob
    queue_as :hooks

    def perform(params)
      event, stack_id, payload = params.with_indifferent_access.values_at('event', 'stack_id', 'payload')
      Hook.deliver(event, stack_id, JSON.parse(payload))
    end
  end
end
