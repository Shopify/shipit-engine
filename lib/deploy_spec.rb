require 'pathname'

class DeploySpec
  BUNDLE_PATH = File.join(Rails.root, 'data', 'bundler')
  Error = Class.new(StandardError)
  SPEC_HINTS = {
    deploy: 'Impossible to detect how to deploy this application. Please define `deploy.override` in your shipit.yml',
    rollback: 'Impossible to detect how to rollback this application. Please define `rollback.override` in your shipit.yml',
    fetch: 'Impossible to detect how to fetch the deployed revision for this application. Please define `fetch` in your shipit.yml',
  }

  class << self
    def load(json)
      if json.present?
        new(JSON.parse(json))
      end
    end

    def dump(spec)
      return unless spec
      JSON.dump(spec.cacheable.config)
    end
  end

  def initialize(config)
    @config = config
  end

  def cacheable
    self
  end

  def config(*keys)
    keys.flatten.reduce(@config) { |h, k| h[k] if h.respond_to?(:[]) }
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

  def dependencies_steps
    config('dependencies', 'override') || discover_dependencies_steps || []
  end
  alias_method :dependencies_steps!, :dependencies_steps

  def deploy_steps
    config('deploy', 'override') || discover_deploy_steps
  end

  def deploy_steps!
    deploy_steps || cant_detect!(:deploy)
  end

  def rollback_steps
    config('rollback', 'override') || discover_rollback_steps
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

  private

  def coerce_task_definition(config)
    config
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
    raise DeploySpec::Error.new(SPEC_HINTS[type])
  end
end
