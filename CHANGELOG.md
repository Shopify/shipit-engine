# Unreleased

* Fix caching of discovered tasks.
* Reconsider all undeployed commits for locking after a rollback has completed (https://github.com/Shopify/shipit-engine/issues/707).
* Marks deploys that are triggered while ignoring safety features (https://github.com/Shopify/shipit-engine/issues/699).
* Automatically prepending `bundle exec` to tasks is deprecated, set `SHIPIT_PREPEND_BUNDLE_EXEC=0` to test the future behaviour before it is enforced.

# 0.19.0

* Fix MRI 2.4 support (https://github.com/attr-encrypted/attr_encrypted/issues/258)
* Add elementary fragment caching to speedup stacks#show
* Expose the `branch` field for stacks.
* Fix `index_tasks_by_stack_and_status`'s order.
* Index `commits` table by `(sha, stack_id)`.
* Index `pull_requests` table by `merge_status`.
* Fix Rails 5.1 compatibility issue when `active_record.belongs_to_required_by_default` is enabled.

# 0.18.1

* Handle environment hash with symbol keys.
* Fix a race condition allowing for duplicate deploys.

# 0.18.0

* Upgrade to Rails 5.1

# 0.17.0

* More explicit removal of dependent records when destroying a stack. Reduces total amount of calls to database and speed up removal.

* Automatically lock impacted commits when a revert is merged. This include the reverted commit as well as all its children up to the revert.

* Allow to lock undeployed commits, to prevent them from being deployed.

* Pull requests in the merge queue which are closed on Github will be marked as merged/cancelled as appropriate.

* TASK_ID environment variable is now available to tasks and deploy scripts.

# 0.16.0

* Move uncommon tasks to drop down menu.

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
