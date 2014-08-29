require 'pathname'

class DeploySpec
  BUNDLE_PATH = File.join(Rails.root, "data", "bundler")
  DEFAULT_BUNDLER_WITHOUT = %w(default production development test staging benchmark debug)
  Error = Class.new(StandardError)

  def initialize(app_dir, env)
    @app_dir = Pathname(app_dir)
    @env = env
  end

  def config(*keys)
    @config ||= load_config
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
    config('dependencies', 'override') || discover_bundler || []
  end

  def deploy_steps
    config('deploy', 'override') || discover_capistrano || discover_gem || cant_detect_deploy_steps
  end

  def rollback_steps
    config('rollback', 'override') || discover_capistrano_rollback || cant_detect_rollback_steps
  end

  def fetch_deployed_revision_steps
    config('fetch') || cant_detect_fetch_deployed_revision_steps
  end

  def discover_gem
    publish_gem if gem?
  end

  def publish_gem
    ["assert-gem-version-tag #{gemspec}", 'bundle exec rake release']
  end

  def discover_bundler
    bundle_install if bundler?
  end

  def bundle_install
    bundle = %(bundle check --path=#{BUNDLE_PATH} || bundle install #{frozen_flag} --path=#{BUNDLE_PATH} --retry=2)
    bundle += " --without=#{bundler_without.join(':')}" unless bundler_without.empty?
    [bundle]
  end

  def bundler_without
    config('dependencies', 'bundler', 'without') || (gem? ? [] : DEFAULT_BUNDLER_WITHOUT)
  end

  def discover_capistrano
    [cap('deploy')] if capistrano?
  end

  def discover_capistrano_rollback
    [cap('deploy:rollback')] if capistrano?
  end

  def gem?
    !!gemspec
  end

  def gemspec
    Dir[@app_dir.join('*.gemspec').to_s].first
  end

  def cap(command)
    bundle_exec("cap $ENVIRONMENT #{command}")
  end

  def bundle_exec(command)
    return command unless bundler?
    "bundle exec #{command}"
  end

  def capistrano?
    @app_dir.join('Capfile').exist?
  end

  def bundler?
    @app_dir.join('Gemfile').exist?
  end

  def has_gemfile_lock?
    @app_dir.join('Gemfile.lock').exist?
  end

  def frozen_flag
    '--frozen' if has_gemfile_lock?
  end

  def cant_detect_deploy_steps
    raise DeploySpec::Error, 'Impossible to detect how to deploy this application. Please define `deploy.override` in your shipit.yml'
  end

  def cant_detect_rollback_steps
    raise DeploySpec::Error, 'Impossible to detect how to rollback this application. Please define `rollback.override` in your shipit.yml'
  end

  def cant_detect_fetch_deployed_revision_steps
    raise DeploySpec::Error, 'Impossible to detect how to rollback this application. Please define `rollback.override` in your shipit.yml'
  end

  def load_config
    if shipit_env_yml.exist?
      SafeYAML.load(shipit_env_yml.read)
    elsif shipit_yml.exist?
      SafeYAML.load(shipit_yml.read)
    else
      {}
    end
  end

  def shipit_env_yml
    @app_dir.join("shipit.#{@env}.yml")
  end

  def shipit_yml
    @app_dir.join('shipit.yml')
  end

end
