namespace :cron do
  task minutely: :environment do
    Stack.refresh_deployed_revisions
  end
end
