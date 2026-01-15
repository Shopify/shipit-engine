# frozen_string_literal: true

module Shipit
  class DeploySpec
    module BundlerDiscovery
      DEFAULT_BUNDLER_WITHOUT = %w[default production development test staging benchmark debug].freeze

      def discover_dependencies_steps
        discover_bundler || super
      end

      def discover_bundler
        bundle_install if bundler?
      end

      def bundle_exec(command)
        if bundler? && dependencies_steps.include?(remove_ruby_version_from_gemfile)
          "bundle exec #{command}"
        else
          command
        end
      end

      def discover_machine_env
        super.merge('BUNDLE_PATH' => bundle_path.to_s)
      end

      def bundle_install
        install_command = %(bundle install --jobs 4 --path #{bundle_path} --retry 2)
        install_command += " --without=#{bundler_without.join(':')}" unless bundler_without.empty?
        [
          remove_ruby_version_from_gemfile,
          (bundle_config_frozen if frozen_mode?),
          install_command
        ].compact
      end

      def remove_ruby_version_from_gemfile
        # Heroku apps often specify a ruby version.
        if /darwin/i.match?(RUBY_PLATFORM)
          # OSX is nitpicky about the -i.
          %q(/usr/bin/sed -i '' '/^ruby\s/d' Gemfile)
        else
          %q(sed -i '/^ruby\s/d' Gemfile)
        end
      end

      def bundle_config_frozen
        'bundle config set --local frozen true'
      end

      def frozen_mode?
        return false unless gemfile_lock_exists?

        config('dependencies', 'bundler', 'frozen') != false
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
        config.merge('steps' => Array(config['steps']))
      end
    end
  end
end
