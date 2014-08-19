class ShipitReminderJob < BackgroundJob
  @queue = :default

  self.timeout = 120

  def perform(params = nil)
    Stack.with_reminder_webhook.pluck(:id).each do |stack_id|
      Resque.enqueue(UndeployedCommitsWebhookJob, stack_id: stack_id)
    end
  end
end
