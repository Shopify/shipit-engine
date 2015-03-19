class EmitEventJob < BackgroundJob
  @queue = :hooks

  def perform(params)
    Hook.deliver(*params.with_indifferent_access.values_at('event', 'stack_id', 'payload'))
  end
end
