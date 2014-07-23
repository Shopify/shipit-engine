class ShipitReminderJob < BackgroundJob
  @queue = :default

  self.timeout = 120

  def perform(params = nil)
    Stack.requires_notification.pluck(:id).each do |stack_id|
      Resque.enqueue(NotifyStackUsersJob, stack_id: stack_id)
    end
  end
end
