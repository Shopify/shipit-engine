require 'pathname'

class DeploySpec
  BUNDLE_PATH = File.join(Rails.root, 'data', 'bundler')
  Error = Class.new(StandardError)

  def initialize(config)
    @config = config
  end

  def config(*keys)
    keys.flatten.reduce(@config) { |h, k| h[k] if h.respond_to?(:[]) }
  end

  def supports_fetch_deployed_revision?
    fetch_deployed_revision_steps
    true
  rescue DeploySpec::Error
    false
  end

  def supports_rollback?
    rollback_steps
    true
  rescue DeploySpec::Error
    false
  end

  def machine_env
    config('machine', 'environment') || {}
  end

  def dependencies_steps
    config('dependencies', 'override') || discover_dependencies_steps || []
  end

  def deploy_steps
    config('deploy', 'override') || discover_deploy_steps || cant_detect_deploy_steps
  end

  def rollback_steps
    config('rollback', 'override') || discover_rollback_steps || cant_detect_rollback_steps
  end

  def fetch_deployed_revision_steps
    config('fetch') || discover_fetch_deployed_revision_steps || cant_detect_fetch_deployed_revision_steps
  end

  private

  def discover_dependencies_steps
    nil
  end

  def discover_deploy_steps
    nil
  end

  def discover_rollback_steps
    nil
  end

  def discover_fetch_deployed_revision_steps
    nil
  end

  def cant_detect_deploy_steps
    raise DeploySpec::Error, 'Impossible to detect how to deploy this application. Please define `deploy.override` in your shipit.yml'
  end

  def cant_detect_rollback_steps
    raise DeploySpec::Error, 'Impossible to detect how to rollback this application. Please define `rollback.override` in your shipit.yml'
  end

  def cant_detect_fetch_deployed_revision_steps
    raise DeploySpec::Error, 'Impossible to detect how to fetch the deployed revision for this application. Please define `fetch` in your shipit.yml'
  end

end
