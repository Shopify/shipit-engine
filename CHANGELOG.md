# Unreleased

# 0.33.0

* Use a Redis cache to store task output, instead of `output_chunks` (deprecate their use).
* Allow to replace the default task execution strategy (#1117).
* Clone repositories with `--recursive` to better handle repos with submodules (#1110).
* Added a `deploy.retries` and `rollback.retries` properties (#1109).
* Added review stacks, which allow to automatically create a stack when a pull request is opened,
  and to delete it when the pull request is closed. This allows to test branch on staging like
  environments (#1102).

# 0.32.0

* Optimize some queries (N+1).
* Added an API endpoint to update stacks.
* Added an API endpoint to trigger rollbacks.
* Added a power user endpoint `/<org>/<repo>` to list all stack of a repository.
* Fix the API response serialization for Ruby 2.6.6+ (#1092).
* Prevent gem released unless the `allowed_push_host` metadata is set in the gemspec (#1037).
* Added a new job `ReapDeadTasksJob` to support cleanup of jobs that are stuck in running, but report as dead.
  * This job runs every minute via the cron rake task.
  * When running this job for the first time, it may transition old zombie tasks, causing any side-effects to fire, like notifications.
* Limit the size of task output logs to 16 MB (#1041)

# 0.31.0

* Update omniauth-github to stop using a deprecated authentication method.
* Interpolate variables in the `links` section of the shipit.yml (#1018).

# 0.30.0

* Add a statistics page for stacks (#931).
* Permit archival of stacks (#969).
* Expose $DEPLOY_URL when running tasks (#981).
* Handle oversized commit messages (#996).
* Add the deployment_url in GitHub deployment records (#1010).
* Allow applications to register extra handlers for GitHub webhooks (#961).
* Display the configured application name in UI

# 0.29.0

* Upgraded to Rails 6.0.

# 0.28.1

* Fix a bug in GitHub API caching causing the cache to grow indefinitely (#935).
* Iterate over 25 rather than 10 commits to try to reconcile force pushed branches (#937).
* Better handle users with only private emails if the permission is available (#922).
* Fix GitHub API status fetching (#928).
* Fix last deployed branch name containing an extra `refs/` (#927).

# 0.28.0

* Fix default ordering of check runs causing retries to display an incorrect status.
* Include stack environment in page title.
* Fix handling of commits with an empty message (#872).

# 0.27.1

* Fix issue with CSRF protection being enabled on webhook and api controllers.

# 0.27.0

* Upgrade to Rails 5.2
* Fix a Postgres compatibility issue (#838).

# 0.26.0

* Record GitHub CheckRuns and display them like statuses.
* Optimize git operations to reduce lock contention.
* Fix kubernetes discovery module to not override user defined tasks.

# 0.25.1

* Improve GitHub API client management. Won't re-auth constantly if cache is disabled, and will keep the connection pool on re-auth.

# 0.25.0

* Stop storing outgoing webhooks in the database for efficiency reasons.
* Various thread safety fixes.
* Use a file lock rather than a redis lock for git locking.
* Handle orphan commits (no parents at all).
* Add a feature to push commit statuses on deploy success (experimental).
* Reject commits with missing statuses from the merge queue.
* Set `ROLLBACK=1` for rollback commands.
* Allow to disable authentication entirely with `SHIPIT_DISABLE_AUTH=1` for easier development.
* Don't pass OAuth scope to GitHub for the authentication process.

# 0.24.0

* Use HTTPS protocol for git operations.
* The default gem release method is now compatible with continuous delivery.
* The default gem release method now assume Shipit can push tags back to the origin repository.
* Set the proper origin remote on working directory repositories.

# 0.23.1

* Fix NoMethodError in CacheDeploySpecJob.

# 0.23.0

* Always fetch from the remote before a task to ensure any newly pushed tag is present.
* Release the browser extension endpoint.
* Add `title` property to tasks to control the task will be displayed in the timeline.
* Allow to configure the merge method used by the merge queue.
* Fix compatibility with GitHub Enterprise installations.

# 0.22.1

* Update omniauth Fix GitHub authentication for enterprise installations.
* Limit delete batches to 50 while purging deliveries to avoid excessive contention.

# 0.22.0

* Converted Shipit to use the new GitHub Apps API, older installations will have to redo their setup.

# 0.21.0

* Dropped MRI 2.2 support since it's EOL.
* The deprecated `Shipit.automatically_prepend_bundle_exec` option was removed.
* Revalidate merge request as soon as they are expired, and not when they could be merged again.
* Allow to configure Shipit to intepret some exit statuses as timeouts instead of regular failures.
* Distinguish deploy timeouts from deploy failures.
* Added blocking statuses. If they are missing or failing, they will prevent deploy even if they were reported on any of the commits in the deploy range.
* Fix shipit.yml updates not being taken into account for the `fetch` command.
* Fix failing membership webhooks for non fully downcase organization names.
* Fix status group links not being disabled when the status url is missing (https://github.com/Shopify/shipit-engine/issues/742).
* Use GitHub ID to refresh users via API to avoid login escaping issues.
* Improve hook deliveries purge mechanism to reduce database contention.
* Pull requests with pending CI will no longer be rejected immediately from the merge queue, they will remain on the queue until CI completes, or the PR needs revalidating.
* Added optional age limits to pull requests (in commit count and time) after which they will be rejected from the merge queue.

# 0.20.1

* Fix hook deliveries purge mechanism that wasn't deleting the correct records.

# 0.20.0

* Change hook deliveries history to only keep 500 for each hooks.
* Fix FetchDeployedRevisionJob failing for stacks with no git cache
* Fix caching of discovered tasks.
* Reconsider all undeployed commits for locking after a rollback has completed (https://github.com/Shopify/shipit-engine/issues/707).
* Marks deploys that are triggered while ignoring safety features (https://github.com/Shopify/shipit-engine/issues/699).
* Automatically prepending `bundle exec` to tasks is deprecated, set `Shipit.automatically_prepend_bundle_exec = false` to test the future behaviour before it is enforced.

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
