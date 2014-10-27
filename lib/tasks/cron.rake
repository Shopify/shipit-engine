namespace :cron do
  desc "Updates deployed revisions"
  task minutely: :environment do
    Stack.refresh_deployed_revisions
  end

  task send_undeployed_commits_reminders: :environment do
    Stack.send_undeployed_commits_reminders
  end

  desc "Rolls-up output chunks for completed deploys older than an hour"
  task rollup: :environment do
    Task.due_for_rollup.find_each(&:rollup_chunks)
  end
end
