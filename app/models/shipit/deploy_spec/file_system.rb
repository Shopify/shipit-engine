# frozen_string_literal: true

module Shipit
  class DeploySpec
    class FileSystem < DeploySpec
      include NpmDiscovery
      include LernaDiscovery
      include PypiDiscovery
      include RubygemsDiscovery
      include CapistranoDiscovery
      include BundlerDiscovery
      include KubernetesDiscovery

      attr_reader :stack

      def initialize(app_dir, stack)
        @app_dir = Pathname(app_dir)
        @env = stack.environment
        @stack = stack
        super(nil)
      end

      def cacheable
        DeploySpec.new(cacheable_config)
      end

      def file(path, root: false)
        if root || directory.blank?
          @app_dir.join(path)
        else
          Pathname.new(File.join(@app_dir, directory, path))
        end
      end

      private

      def cacheable_config
        (config || {}).deep_merge(
          'merge' => {
            'require' => merge_request_required_statuses,
            'ignore' => merge_request_ignored_statuses,
            'revalidate_after' => revalidate_merge_requests_after&.to_i,
            'method' => merge_request_merge_method,
            'max_divergence' => {
              'commits' => max_divergence_commits&.to_i,
              'age' => max_divergence_age&.to_i
            }
          },
          'ci' => {
            'hide' => hidden_statuses,
            'allow_failures' => soft_failing_statuses,
            'require' => required_statuses,
            'blocking' => blocking_statuses
          },
          'machine' => {
            'environment' => discover_machine_env.merge(machine_env),
            'directory' => directory,
            'cleanup' => true
          },
          'review' => {
            'checklist' => review_checklist,
            'monitoring' => review_monitoring,
            'checks' => review_checks
          },
          'plugins' => plugins,
          'status' => {
            'context' => release_status_context,
            'delay' => release_status_delay
          },
          'dependencies' => { 'override' => dependencies_steps },
          'provision' => { 'handler_name' => provisioning_handler_name },
          'deploy' => {
            'override' => deploy_steps,
            'variables' => deploy_variables.map(&:to_h),
            'max_commits' => maximum_commits_per_deploy,
            'interval' => pause_between_deploys,
            'retries' => retries_on_deploy
          },
          'rollback' => {
            'override' => rollback_steps,
            'retries' => retries_on_rollback
          },
          'fetch' => fetch_deployed_revision_steps,
          'tasks' => cacheable_tasks
        )
      end

      def cacheable_tasks
        discover_task_definitions.transform_values { |c| coerce_task_definition(c) }
      end

      def config(*)
        @config ||= load_config
        super
      end

      def load_config
        return if config_file_path.nil?

        if !Shipit.respect_bare_shipit_file? && config_file_path.to_s.end_with?(*bare_shipit_filenames)
          return { 'deploy' => { 'pre' => [shipit_not_obeying_bare_file_echo_command, 'exit 1'] } }
        end

        config_obj = read_config(config_file_path)
        build_config(config_file_path, config_obj)
      end

      def shipit_file_names_in_priority_order
        [
          "#{app_name}.#{@env}.yml",
          ".shipit/#{app_name}.#{@env}.yml",

          "#{app_name}.yml",
          ".shipit/#{app_name}.yml",

          "shipit.#{@env}.yml",
          ".shipit/#{@env}.yml",

          "shipit.yml",
          ".shipit/shipit.yml"
        ].uniq
      end

      def bare_shipit_filenames
        ["#{app_name}.yml", "shipit.yml", ".shipit/#{app_name}.yml", ".shipit/shipit.yml"].uniq
      end

      def config_file_path
        shipit_file_names_in_priority_order.each do |filename|
          path = file(filename, root: true)
          return path if path.exist?
        end

        nil
      end

      def app_name
        @app_name ||= Shipit.app_name.downcase
      end

      SHIPIT_CONFIG_INHERIT_FROM_KEY = "inherit_from"
      def build_config(path, config_obj)
        return config_obj if config_obj.blank? || !config_obj.key?(SHIPIT_CONFIG_INHERIT_FROM_KEY)

        inherits_from_path = path.dirname.join(config_obj.delete(SHIPIT_CONFIG_INHERIT_FROM_KEY))
        if inherits_from_path.exist?
          inherits_config_obj = read_config(inherits_from_path)
          config_obj = inherits_config_obj.deep_merge(config_obj)
          path = inherits_from_path
        end

        build_config(path, config_obj)
      end

      def read_config(path)
        SafeYAML.load(path.read) if path.exist?
      end

      def shipit_not_obeying_bare_file_echo_command
        <<~WARNING_MESSAGE
          echo \"\e[1;31mShipit is configured to ignore the bare '#{app_name}.yml' file.
          Please rename this file to more specifically include the environment name.
          Deployments will fail until a valid '#{app_name}.#{@env}.yml' file is found.\e[0m\"
        WARNING_MESSAGE
      end
    end
  end
end
