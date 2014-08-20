namespace :cron do
  task minutely: :environment do
    Stack.sharded(6, Time.now.min % 6).refresh_deployed_revisions
  end

  task send_undeployed_commits_reminders: :environment do
    Stack.send_undeployed_commits_reminders
  end
end
