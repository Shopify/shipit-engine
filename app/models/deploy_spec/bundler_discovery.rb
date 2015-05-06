class DeploySpec
  module BundlerDiscovery
    DEFAULT_BUNDLER_WITHOUT = %w(default production development test staging benchmark debug)

    def discover_dependencies_steps
      discover_bundler || super
    end

    def discover_bundler
      bundle_install if bundler?
    end

    def bundle_exec(command)
      return command unless bundler?
      "bundle exec #{command}"
    end

    def bundle_install
      bundle = %(bundle check --path=#{bundle_path} || bundle install #{frozen_flag} --path=#{bundle_path} --retry=2)
      bundle += " --without=#{bundler_without.join(':')}" unless bundler_without.empty?
      [remove_ruby_version_from_gemfile, bundle]
    end

    def remove_ruby_version_from_gemfile
      %q(sed -i '/^ruby\s/d' Gemfile) # Heroku apps often specify a ruby version.
    end

    def frozen_flag
      '--frozen' if gemfile_lock_exists?
    end

    def bundler_without
      config('dependencies', 'bundler', 'without') || (gem? ? [] : DEFAULT_BUNDLER_WITHOUT)
    end

    def bundler?
      file('Gemfile').exist?
    end

    def gemfile_lock_exists?
      file('Gemfile.lock').exist?
    end

    def coerce_task_definition(config)
      return super unless bundler?
      config['steps'] ||= []
      config['steps'] = config['steps'].map(&method(:bundle_exec))
      config
    end
  end
end
