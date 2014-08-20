namespace :cron do
  desc "Updates deployed revisions"
  task minutely: :environment do
    Stack.sharded(6, Time.now.min % 6).refresh_deployed_revisions
  end

  task send_undeployed_commits_reminders: :environment do
    Stack.send_undeployed_commits_reminders
  end

  desc "Rolls-up output chunks for completed deploys older than an hour"
  task rollup: :environment do
    Deploy.due_for_rollup.each(&:rollup_chunks)
  end
end
