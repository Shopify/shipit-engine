every 1.minute do
  rake 'cron:minutely'
end

every 30.minutes do
  rake 'cron:send_undeployed_commits_reminders'
end
