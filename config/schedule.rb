every 1.minute do
  rake 'cron:minutely'
end

every 1.hour do
  rake 'cron:rollup'
end

every 1.hour do
  rake 'cron:refresh_users'
end
