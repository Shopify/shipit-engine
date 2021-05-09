require 'prometheus/client'

prometheus = Prometheus::Client.registry

prometheus.register(Prometheus::Client::Counter.new(:shipit_predictive_branch_count, docstring: 'Count predictive branches', labels: [:pipeline, :stack, :status]))
prometheus.register(Prometheus::Client::Counter.new(:shipit_predictive_branch_duration_minutes_sum, docstring: 'Summarize predictive branches durations in minutes', labels: [:pipeline, :stack, :status]))

prometheus.register(Prometheus::Client::Counter.new(:shipit_predictive_build_count, docstring: 'Count predictive builds', labels: [:pipeline, :status]))
prometheus.register(Prometheus::Client::Counter.new(:shipit_predictive_build_duration_minutes_sum, docstring: 'Summarize predictive builds durations in minutes', labels: [:pipeline, :status]))

prometheus.register(Prometheus::Client::Counter.new(:shipit_ci_task_count, docstring: 'Count CI tasks', labels: [:pipeline, :stack, :type, :status]))
prometheus.register(Prometheus::Client::Counter.new(:shipit_ci_task_duration_minutes_sum, docstring: 'Summarize CI tasks durations in minutes', labels: [:pipeline, :stack, :type, :status]))

prometheus.register(Prometheus::Client::Counter.new(:shipit_task_count, docstring: 'Count tasks', labels: [:pipeline, :stack, :type, :status]))
prometheus.register(Prometheus::Client::Counter.new(:shipit_task_duration_seconds_sum, docstring: 'Summarize tasks durations', labels: [:pipeline, :stack, :type, :status]))

prometheus.register(Prometheus::Client::Counter.new(:merge_requests_enqueue_count, docstring: 'Count enqueued PRs', labels: [:pipeline, :stack, :mode, :status]))
prometheus.register(Prometheus::Client::Counter.new(:merge_requests_dequeue_count, docstring: 'Count dequeued PRs', labels: [:pipeline, :stack, :mode, :status]))
prometheus.register(Prometheus::Client::Counter.new(:merge_requests_dequeue_duration, docstring: 'Summarize dequeued PRs durations', labels: [:pipeline, :stack, :mode, :status]))