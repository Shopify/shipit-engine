# Unreleased

*   Do not prepend `bundle exec` to custom tasks if `depedencies.override` is set.

    Otherwise there isn't any way to opt-out from automatic bundler discovery.
