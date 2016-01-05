module Shipit
  class DeploySpec
    class FileSystem < DeploySpec
      include PypiDiscovery
      include RubygemsDiscovery
      include CapistranoDiscovery
      include BundlerDiscovery

      def initialize(app_dir, env)
        @app_dir = Pathname(app_dir)
        @env = env
      end

      def cacheable
        DeploySpec.new(cacheable_config)
      end

      private

      def cacheable_config
        (config || {}).deep_merge(
          'ci' => {
            'hide' => hidden_statuses,
            'allow_failures' => soft_failing_statuses,
            'require' => required_statuses,
          },
          'machine' => {'environment' => machine_env, 'directory' => directory},
          'review' => {
            'checklist' => review_checklist,
            'monitoring' => review_monitoring,
            'checks' => review_checks,
          },
          'plugins' => plugins,
          'dependencies' => {'override' => dependencies_steps},
          'deploy' => {'override' => deploy_steps, 'variables' => deploy_variables.map(&:to_h)},
          'rollback' => {'override' => rollback_steps},
          'fetch' => fetch_deployed_revision_steps,
          'tasks' => cacheable_tasks,
        )
      end

      def cacheable_tasks
        (config('tasks') || {}).map { |k, c| [k, coerce_task_definition(c)] }.to_h
      end

      def config(*)
        @config ||= load_config
        super
      end

      def load_config
        read_config(file("shipit.#{@env}.yml")) || read_config(file('shipit.yml'))
      end

      def read_config(path)
        SafeYAML.load(path.read) if path.exist?
      end

      def file(path)
        @app_dir.join(path)
      end
    end
  end
end
