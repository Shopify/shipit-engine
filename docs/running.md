# Shipit Operational Guide

Some of this is common rails knowledge, but documented here for those that are less familiar.

## Required Software

*  git

## Database Setup

```sh
/path/to/bin/rake db:create db:create shipit:install:migrations db:migrate
```

## Cron Jobs

There are two cron jobs that need to run, here's an example crontab file:

```crontab
* * * * * /path/to/bin/rails cron:minutely
0 * * * * /path/to/bin/rails cron:hourly
```

## Sidekiq

You must run sidekiq in addition to Rails.

```sh
/path/to/bin/bundle exec sidekiq -e production -C config/sidekiq.yml
```

## SSH Keys

Shipit will use ssh to clone your repo, you'll need to add the github address to the `~/.ssh/known_hosts` and
add a set of ssh keys to the github app. Ideally this key will be added to a user that has read-only
permissions to the organization.

## Capistrano

If your app can be deployed now with Capistrano, Shipit can automatically deploy your app, if not, you'll need
to add a shipit.yml to specify how thos steps will work.
