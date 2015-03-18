class DeliverHookJob < BackgroundJob
  @queue = :hooks

  def perform(params)
    Delivery.find(params[:delivery_id]).send!
  end
end
