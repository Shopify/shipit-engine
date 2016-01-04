namespace :cron do
  desc "Updates deployed revisions"
  task minutely: :environment do
    Shipit::Stack.refresh_deployed_revisions
  end

  desc "Rolls-up output chunks for completed deploys older than an hour"
  task rollup: :environment do
    Shipit::Task.due_for_rollup.find_each(&:schedule_rollup_chunks)
  end

  task refresh_users: :environment do
    Shipit::User.refresh_shard(Time.now.hour % 24, 24)
  end
end
