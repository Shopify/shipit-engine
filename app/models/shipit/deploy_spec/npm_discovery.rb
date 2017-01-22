require 'json'

module Shipit
  class DeploySpec
    module NpmDiscovery
      def discover_dependencies_steps
        discover_package_json || super
      end

      def discover_package_json
        npm_install if (yarn? || npm?)
      end

      def npm_install
        [js_command('install --no-progress')]
      end

      def discover_review_checklist
        discover_yarn_checklist || discover_npm_checklist || super
      end

      def discover_yarn_checklist
        [%(<strong>Don't forget version and tag before publishing!</strong> You can do this with:<br/>
          yarn version --new-version <strong>&lt;major|minor|patch&gt;</strong> && git push --tags</pre>)] if yarn?
      end

      def discover_npm_checklist
        [%(<strong>Don't forget version and tag before publishing!</strong> You can do this with:<br/>
          npm version <strong>&lt;major|minor|patch&gt;</strong> && git push --tags</pre>)] if npm?
      end

      def npm?
        public?
      end

      def public?
        file = package_json
        return false unless file.exist?

        JSON.parse(file.read)['private'].blank?
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
        publish_npm_package if (yarn? || npm?)
      end

      def discover_deploy_steps
        discover_npm_package || super
      end

      def publish_npm_package
        check_tags = 'assert-npm-version-tag'
        publish = js_command('publish')

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
