namespace :cron do
  desc "Updates deployed revisions"
  task minutely: :environment do
    Shipit::Stack.refresh_deployed_revisions
    Shipit::Stack.schedule_continuous_delivery
    Shipit::GithubStatus.refresh_status
    Shipit::PullRequest.schedule_merges
  end

  task hourly: [:rollup, :purge_deliveries, :refresh_users]

  desc "Rolls-up output chunks for completed deploys older than an hour"
  task rollup: :environment do
    Shipit::Task.due_for_rollup.find_each(&:schedule_rollup_chunks)
  end

  desc "Delete old hook delivery records"
  task purge_deliveries: :environment do
    Shipit::Delivery.due_for_deletion.delete_all
  end

  task refresh_users: :environment do
    Shipit::User.refresh_shard(Time.now.hour % 24, 24)
  end
end
