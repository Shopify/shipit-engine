require 'pathname'

module Shipit
  class DeploySpec
    Error = Class.new(StandardError)

    class << self
      def load(json)
        config = json.blank? ? {} : JSON.parse(json)
        new(config)
      end

      def dump(spec)
        JSON.dump(spec.cacheable.config) if spec
      end

      def bundle_path
        Rails.root.join('data/bundler')
      end
    end

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
        if hash.is_a?(Hash)
          hash.fetch(key) { return default.call }
        else
          return default.call
        end
      end
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
        config('dependencies', 'override') { discover_dependencies_steps || [] }
      end
    end
    alias_method :dependencies_steps!, :dependencies_steps

    def maximum_commits_per_deploy
      config('deploy', 'max_commits')
    end

    def pause_between_deploys
      Duration.parse(config('deploy', 'interval') { 0 })
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

    def rollback_steps
      around_steps('rollback') do
        config('rollback', 'override') { discover_rollback_steps }
      end
    end

    def rollback_steps!
      rollback_steps || cant_detect!(:rollback)
    end

    def fetch_deployed_revision_steps
      config('fetch') || discover_fetch_deployed_revision_steps
    end

    def fetch_deployed_revision_steps!
      fetch_deployed_revision_steps || cant_detect!(:fetch)
    end

    def task_definitions
      (config('tasks') || {}).map { |name, definition| TaskDefinition.new(name, coerce_task_definition(definition)) }
    end

    def find_task_definition(id)
      TaskDefinition.new(id, coerce_task_definition(config('tasks', id)) || task_not_found!(id))
    end

    def filter_deploy_envs(env)
      EnvironmentVariables.with(env).permit(deploy_variables)
    end

    def filter_task_envs(id, env)
      find_task_definition(id).filter_envs(env)
    end

    def review_checklist
      (config('review', 'checklist') || discover_review_checklist || []).map(&:strip).select(&:present?)
    end

    def review_monitoring
      (config('review', 'monitoring') || []).select(&:present?)
    end

    def hidden_statuses
      Array.wrap(config('ci', 'hide'))
    end

    def required_statuses
      Array.wrap(config('ci', 'require'))
    end

    def soft_failing_statuses
      Array.wrap(config('ci', 'allow_failures'))
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

    def around_steps(section)
      steps = yield
      return unless steps
      config(section, 'pre') { [] } + steps + config(section, 'post') { [] }
    end

    def coerce_task_definition(config)
      config
    end

    def discover_review_checklist
    end

    def discover_dependencies_steps
    end

    def discover_deploy_steps
    end

    def discover_rollback_steps
    end

    def discover_fetch_deployed_revision_steps
    end

    def task_not_found!(id)
      raise TaskDefinition::NotFound.new("No definition for task #{id.inspect}")
    end

    def cant_detect!(type)
      raise DeploySpec::Error.new(I18n.t("deploy_spec.hint.#{type}"))
    end
  end
end
