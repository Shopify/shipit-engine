class DeliverHookJob < BackgroundJob
  queue_as :hooks

  def perform(params)
    Delivery.find(params[:delivery_id]).send!
  end
end
