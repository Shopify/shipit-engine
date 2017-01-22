require 'json'

module Shipit
  class DeploySpec
    module NpmDiscovery
      def discover_dependencies_steps
        discover_package_json || super
      end

      def discover_package_json
        (yarn_install if yarn?) || (npm_install if npm?)
      end

      def yarn_install
        [%(yarn install --no-progress)]
      end

      def npm_install
        [%(npm install --no-progress)]
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

      def discover_deploy_steps
        (publish_yarn_package if yarn?) || (publish_npm_package if npm?) || super
      end

      def publish_yarn_package
        check_tags = 'assert-npm-version-tag'
        publish = 'yarn publish'

        [check_tags, publish]
      end

      def publish_npm_package
        check_tags = 'assert-npm-version-tag'
        publish = 'npm publish'

        [check_tags, publish]
      end
    end
  end
end
