namespace :cron do
  desc "Updates deployed revisions"
  task minutely: :environment do
    Stack.refresh_deployed_revisions
  end

  desc "Rolls-up output chunks for completed deploys older than an hour"
  task rollup: :environment do
    Task.due_for_rollup.find_each(&:schedule_rollup_chunks)
  end

  task refresh_users: :environment do
    User.refresh_shard(Time.now.hour % 24, 24)
  end
end
