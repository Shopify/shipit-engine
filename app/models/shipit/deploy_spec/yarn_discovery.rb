module Shipit
  class DeploySpec
    module YarnDiscovery
      def discover_dependencies_steps
        discover_yarn || super
      end

      def discover_yarn
        yarn_install if yarn?
      end

      def yarn_install
        [%(yarn install --no-progress)]
      end

      def discover_review_checklist
        discover_yarn_checklist || super
      end

      def discover_yarn_checklist
        [%(<strong>Don't forget version and tag before publishing!</strong> You can do this with:<br/>
          yarn version --new-version <strong>&lt;major|minor|patch&gt;</strong> && git push --tags</pre>)] if yarn?
      end

      def yarn?
        yarn_lock.exist? && public?
      end

      def yarn_lock
        file('./yarn.lock')
      end

      def discover_yarn_package
        publish_yarn_package if yarn?
      end

      def discover_deploy_steps
        discover_yarn_package || super
      end

      def publish_yarn_package
        check_tags = 'assert-npm-version-tag'
        publish = 'yarn publish'

        [check_tags, publish]
      end
    end
  end
end
