# Task execution strategies

# Default

For most applications, the default execution strategy is sufficient. This strategy processes a task within the context of a shipit-engine Sidekiq worker. shipit-engine provides the `Shipit::TaskExecutionStrategy::Default` strategy to do this - on a vanilla shipit-engine instance _this_ is the registered default execution strategy.

# Custom task execution strategies

## Registering a strategy for a particular type of task

1. Create a custom TaskExecutionStrategy by extending `Shipit::TaskExecutionStrategy::Base` and implementing the `#execute` method. The `Shipit::Task` to be processed is available as the `task` local - courtesy of the inherited `Shipit::TaskExecutionStrategy::Base#initialize` method:
    ```ruby
    class KubernetesPodExecutionStrategy < Shipit::TaskExecutionStrategy::Base
      def execute
        # Example: apply kubernetes templates to create a pod in which the job should
        # be executed passing along the task to be executed
        #
        # Consider running a Kubernetes Pod of the host-application's image
        # whose command - in turn - runs a rake task invoking the
        # Shipit::TaskExecutionStrategy::Default stratgy on the task.
        #
        # Pseudo code below:
        kube.apply(task_execution_pod_templte)
      end

      def task_execution_pod_template
        <<~YAML
        ...
          command: [ "bin/rails" ]
          args: [ "shipit:task:run[#{task.id}]" ]
        ...
        YAML
      end
    end
    ```
2. Register the custom strategy as the strategy to use for the a particular task type. For example, the following uses the above `KubernetesPodExecutionStrategy` for any `Shipit::Deploy` type task:
    ```ruby
    # probably in the host application's shipit initializer
    Shipit::TaskExecutionStrategy.register(Shipit::Deploy, KubernetesPodExecutionStrategy)
    ```

## Registering a new host-application-wide default task execution strategy

The `Shipit::TaskExecutionStrategy` also provides a way to replace the system-wide default execution strategy. To do so, one would create a custom execution strategy as described above, and register it like so:

```ruby
Shipit::TaskExecutionStrategy.default = KubernetesPodExecutionStrategy
```
