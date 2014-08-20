namespace :cron do
  task minutely: :environment do
    Stack.sharded(6, Time.now.min % 6).refresh_deployed_revisions
  end

  task shipit_reminder: :environment do
    Resque.enqueue(ShipitReminderJob)
  end
end
