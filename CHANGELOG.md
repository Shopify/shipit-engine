# Unreleased

# 0.14.0

*   Do not prepend `bundle exec` to custom tasks if `depedencies.override` is set.

    Otherwise there isn't any way to opt-out from automatic bundler discovery.

*   Command `variable` now allows a `select` to take a list of values, rather than a text field.

*   Fix stack header CSS when there is many custom tasks.

*   Handle GitHub repositories with no commits at all.

*   Add `deploy-to-gke` script, for deploying to Google Container Engine.
