namespace :cron do
  task tick: :environment do
    Stack.refresh_deployed_revisions
  end
end
