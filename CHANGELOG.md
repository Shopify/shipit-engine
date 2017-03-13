# Unreleased

* Pull requests in the merge queue which are closed on Github will be marked as merged/cancelled as appropriate.

# 0.16.0

* Add a CCMenu compatible API.

* Implement an optional merge queue, allowing to schedule pull requests to be merged as soon as the targeted branch is clear.

* Prevent `commit_status` and `deployable_status` hooks from firing if the commit is already deployed.

# 0.15.0

*   Add NPM package publishing support with either yarn or npm.

*   Add a `kubernetes` section in `shipit.yml` for first class k8s support (Still alpha).

*   Disregard GitHub's Cache-Control max-age directives, because they impose a 60 seconds resolution
    which is way too slow.

*   Bust caches from a delayed background job to avoid deadlocks on heavy traffic installations.

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
