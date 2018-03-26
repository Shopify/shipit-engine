require 'json'

module Shipit
  class DeploySpec
    module NpmDiscovery
      # https://docs.npmjs.com/cli/publish
      PUBLIC = 'public'.freeze
      PRIVATE = 'restricted'.freeze
      VALID_ACCESS = [PUBLIC, PRIVATE].freeze
      NPM_REGISTRY = "https://registry.npmjs.org/".freeze

      def discover_dependencies_steps
        discover_package_json || super
      end

      def discover_package_json
        npm_install if yarn? || npm?
      end

      def npm_install
        [js_command('install --no-progress')]
      end

      def discover_review_checklist
        discover_yarn_checklist || discover_npm_checklist || super
      end

      def discover_yarn_checklist
        if yarn?
          [%(<strong>Don't forget version and tag before publishing!</strong> You can do this with:<br/>
            yarn version --new-version <strong>&lt;major|minor|patch&gt;</strong>
            && git push --follow-tags</pre>)]
        end
      end

      def discover_npm_checklist
        if npm?
          [%(<strong>Don't forget version and tag before publishing!</strong> You can do this with:<br/>
            npm version <strong>&lt;major|minor|patch&gt;</strong>
            && git push --follow-tags</pre>)]
        end
      end

      def npm?
        public?
      end

      def public?
        file = package_json
        return false unless file.exist?

        JSON.parse(file.read)['private'].blank?
      end

      def dist_tag(version)
        # Pre-release SemVer tags such as 'beta', 'alpha', 'rc' and 'next'
        # are treated as 'next' npm dist-tags.
        # An 1.0.0-beta.1 would be installable using both:
        # `yarn add package@1.0.0-beta.1` and `yarn add package@next`
        return 'next' if ['-beta', '-alpha', '-rc', '-next'].any? { |tag| version.include? tag }
        'latest'
      end

      def package_json
        file('package.json')
      end

      def yarn?
        yarn_lock.exist? && public?
      end

      def yarn_lock
        file('./yarn.lock')
      end

      def discover_npm_package
        publish_npm_package if yarn? || npm?
      end

      def discover_deploy_steps
        discover_npm_package || super
      end

      def package_version
        JSON.parse(package_json.read)['version']
      end

      def publish_config
        JSON.parse(package_json.read)['publishConfig']
      end

      def publish_config_access
        config = publish_config

        # default to private deploy when we enforce a publishConfig
        if enforce_publish_config?
          return PRIVATE if config.blank?
          config['access'] || PRIVATE
        end

        return PUBLIC if config.blank?
        config['access'] || PUBLIC
      end

      def package_name
        JSON.parse(package_json.read)['name']
      end

      def scoped_package?
        package_name.start_with?('@shopify')
      end

      def enforce_publish_config?
        enforce = Shipit.enforce_publish_config
        return false if enforce.nil? || enforce.to_s == "0"
        true
      end

      def valid_publish_config?
        return true unless enforce_publish_config?
        return false if Shipit.private_npm_registry.nil?
        return false if publish_config.blank?
        return true if publish_config_access == PUBLIC

        valid_publish_config_access? && private_scoped_package?
      end

      def valid_publish_config_access?
        VALID_ACCESS.include?(publish_config_access)
      end

      # ensure private packages are scoped
      def private_scoped_package?
        publish_config_access == PRIVATE && scoped_package?
      end

      def local_npmrc
        file(".npmrc")
      end

      def npmrc_contents(registry)
        "always-auth=true\n#{registry}"
      end

      def registry
        prefix = scoped_package? ? "@shopify:registry" : "registry"
        if publish_config_access == PUBLIC
          return "#{prefix}=#{NPM_REGISTRY}"
        end

        "#{prefix}=#{Shipit.private_npm_registry}"
      end

      def generate_local_npmrc
        contents = npmrc_contents(registry)
        File.write(local_npmrc, contents) unless local_npmrc.exist?
      end

      def publish_npm_package
        return ['misconfigured-npm-publish-config'] unless valid_publish_config?

        generate_local_npmrc
        check_tags = 'assert-npm-version-tag'
        # `yarn publish` requires user input, so always use npm.
        publish = "npm publish --tag #{dist_tag(package_version)} --access #{publish_config_access}"

        [check_tags, publish]
      end

      def js_command(command_args)
        runner = if yarn?
          'yarn'
        else
          'npm'
        end

        "#{runner} #{command_args}"
      end
    end
  end
end
