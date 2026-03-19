# frozen_string_literal: true

require 'pathname'

module Shipit
  class DeploySpec
    Error = Class.new(StandardError)

    class << self
      attr_accessor :pretty_generate

      def load(json)
        config = json.blank? ? {} : JSON.parse(json)
        new(config)
      end

      def dump(spec)
        return unless spec

        if pretty_generate?
          JSON.pretty_generate(spec.cacheable.config)
        else
          JSON.dump(spec.cacheable.config)
        end
      end

      def bundle_path
        Rails.root.join('data', 'bundler')
      end

      def pretty_generate?
        @pretty_generate
      end
    end

    self.pretty_generate = false

    SAFE_DEPLOY_COMMAND_PREFIXES = %w[
      production-platform-next
      kubernetes-deploy
      kubernetes-restart
    ].freeze

    def initialize(config)
      @config = config
    end

    delegate :bundle_path, to: :class

    def cacheable
      self
    end

    def config(*keys, &default)
      default ||= -> { nil }
      keys.flatten.reduce(@config) do |hash, key|
        return default.call unless hash.is_a?(Hash)

        hash.fetch(key) { return default.call }
      end
    end

    def blank?
      config.empty?
    end

    def supports_fetch_deployed_revision?
      fetch_deployed_revision_steps.present?
    end

    def supports_rollback?
      rollback_steps.present?
    end

    def machine_env
      config('machine', 'environment') || {}
    end

    def directory
      config('machine', 'directory')
    end

    def dependencies_steps
      around_steps('dependencies') do
        config('dependencies', 'override') do
          if skip_dependencies_for_production_platform?
            Rails.logger.warn(
              "Skipping dependency installation: stack uses production_platform " \
              "and has no deploy steps requiring local dependencies. " \
              "To override, set `dependencies.override` in your shipit.yml."
            )
            []
          else
            discover_dependencies_steps || []
          end
        end
      end
    end
    alias dependencies_steps! dependencies_steps

    def maximum_commits_per_deploy
      config('deploy', 'max_commits') { 8 }
    end

    def release_status?
      !!release_status_context
    end

    def release_status_context
      config('status', 'context')
    end

    def release_status_delay
      return unless delay = config('status', 'delay') { config('deploy', 'interval') { 0 } }

      Duration.parse(delay)
    end

    def pause_between_deploys
      Duration.parse(config('deploy', 'interval') { 0 })
    end

    def provisioning_handler_name
      config('provision', 'handler_name')
    end

    def deploy_steps
      around_steps('deploy') do
        config('deploy', 'override') { discover_deploy_steps }
      end
    end

    def deploy_steps!
      deploy_steps || cant_detect!(:deploy)
    end

    def deploy_variables
      Array.wrap(config('deploy', 'variables')).map(&VariableDefinition.method(:new))
    end

    def default_deploy_env
      deploy_variables.map { |v| [v.name, v.default] }.to_h
    end

    def retries_on_deploy
      config('deploy', 'retries') { nil }
    end

    def rollback_steps
      around_steps('rollback') do
        config('rollback', 'override') { discover_rollback_steps }
      end
    end

    def rollback_steps!
      rollback_steps || cant_detect!(:rollback)
    end

    def rollback_variables
      if config('rollback', 'variables').nil?
        # For backwards compatibility, fallback to using deploy_variables if no explicit rollback variables are set
        deploy_variables
      else
        Array.wrap(config('rollback', 'variables')).map(&VariableDefinition.method(:new))
      end
    end

    def retries_on_rollback
      config('rollback', 'retries') { nil }
    end

    def fetch_deployed_revision_steps
      config('fetch') || discover_fetch_deployed_revision_steps
    end

    def fetch_deployed_revision_steps!
      fetch_deployed_revision_steps || cant_detect!(:fetch)
    end

    def task_definitions
      discover_task_definitions.merge(config('tasks') || {}).map do |name, definition|
        TaskDefinition.new(name, coerce_task_definition(definition))
      end
    end

    def find_task_definition(id)
      definition = config('tasks', id) || discover_task_definitions[id]
      TaskDefinition.new(id, coerce_task_definition(definition) || task_not_found!(id))
    end

    def filter_deploy_envs(env)
      EnvironmentVariables.with(env).permit(deploy_variables)
    end

    def filter_rollback_envs(env)
      EnvironmentVariables.with(env).permit(rollback_variables)
    end

    def review_checklist
      (config('review', 'checklist') || discover_review_checklist || []).map(&:strip).select(&:present?)
    end

    def review_monitoring
      (config('review', 'monitoring') || []).select(&:present?)
    end

    def hidden_statuses
      Array.wrap(config('ci', 'hide')) + [release_status_context].compact
    end

    def required_statuses
      (Array.wrap(config('ci', 'require')) + blocking_statuses).uniq
    end

    def soft_failing_statuses
      Array.wrap(config('ci', 'allow_failures'))
    end

    def blocking_statuses
      Array.wrap(config('ci', 'blocking'))
    end

    def merge_request_merge_method
      method = config('merge', 'method')
      method if %w[merge rebase squash].include?(method)
    end

    def merge_request_required_statuses
      if config('merge', 'require') || config('merge', 'ignore')
        Array.wrap(config('merge', 'require'))
      else
        required_statuses
      end
    end

    def merge_request_ignored_statuses
      if config('merge', 'require') || config('merge', 'ignore')
        Array.wrap(config('merge', 'ignore')) + [release_status_context].compact
      else
        soft_failing_statuses | hidden_statuses
      end
    end

    def revalidate_merge_requests_after
      return unless timeout = config('merge', 'revalidate_after')

      begin
        Duration.parse(timeout)
      rescue Duration::ParseError
      end
    end

    def max_divergence_commits
      config('merge', 'max_divergence', 'commits')
    end

    def max_divergence_age
      return unless timeout = config('merge', 'max_divergence', 'age')

      begin
        Duration.parse(timeout)
      rescue Duration::ParseError
      end
    end

    def review_checks
      config('review', 'checks') || []
    end

    def plugins
      config('plugins') || {}
    end

    def clear_working_directory?
      config('machine', 'cleanup') { true }
    end

    def links
      config('links') { {} }
    end

    private

    def production_platform?
      config('production_platform').present?
    end

    def skip_dependencies_for_production_platform?
      return false unless production_platform?

      # Only check explicitly configured steps. If deploy/rollback rely on auto-discovery
      # (no override), we conservatively assume dependencies may be needed.
      # Similarly, discovered task definitions (e.g., kubernetes-restart) are inherently
      # safe commands and don't need to be checked here.
      all_steps = Array(config('deploy', 'override')) +
                  Array(config('deploy', 'pre')) +
                  Array(config('deploy', 'post')) +
                  Array(config('rollback', 'override')) +
                  Array(config('rollback', 'pre')) +
                  Array(config('rollback', 'post')) +
                  all_task_steps

      all_steps = all_steps.compact
      return false if all_steps.empty?

      all_steps.all? { |step| safe_deploy_command?(step) }
    end

    def all_task_steps
      task_configs = config('tasks') || {}
      task_configs.values.flat_map { |td| Array(td['steps']) }
    end

    def safe_deploy_command?(step)
      step = step.to_s.strip
      return true if step.empty?

      SAFE_DEPLOY_COMMAND_PREFIXES.any? { |prefix| step == prefix || step.start_with?("#{prefix} ") }
    end

    def around_steps(section)
      steps = yield
      return unless steps

      config(section, 'pre') { [] } + steps + config(section, 'post') { [] }
    end

    def coerce_task_definition(config)
      config
    end

    def discover_review_checklist; end

    def discover_task_definitions
      config('tasks') || {}
    end

    def discover_dependencies_steps; end

    def discover_deploy_steps; end

    def discover_rollback_steps; end

    def discover_fetch_deployed_revision_steps; end

    def discover_machine_env
      {}
    end

    def task_not_found!(id)
      raise TaskDefinition::NotFound, "No definition for task #{id.inspect}"
    end

    def cant_detect!(type)
      raise DeploySpec::Error, I18n.t("deploy_spec.hint.#{type}")
    end
  end
end
