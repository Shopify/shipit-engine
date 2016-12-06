# Unreleased

*   Properly delete statuses when a commit is destroyed.

*   Properly set default env on deploys triggered by continuous delivery.

*   Add `cron:purge_deliveries` task to only keep one month of hook delivery history.

*   Add `cron:hourly` task to call `cron:rollup`, `cron:refresh_users` and `cron:purge_deliveries` together.

# 0.14.0

*   Do not prepend `bundle exec` to custom tasks if `depedencies.override` is set.

    Otherwise there isn't any way to opt-out from automatic bundler discovery.

*   Command `variable` now allows a `select` to take a list of values, rather than a text field.

*   Fix stack header CSS when there is many custom tasks.

*   Handle GitHub repositories with no commits at all.

*   Add `deploy-to-gke` script, for deploying to Google Container Engine.
