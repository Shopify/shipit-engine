require 'json'

module Shipit
  class DeploySpec
    module LernaDiscovery
      def discover_dependencies_steps
        discover_lerna_json || super
      end

      def discover_lerna_json
        lerna_install if lerna?
      end

      def lerna_install
        [js_command('install --no-progress'), 'node_modules/.bin/lerna bootstrap']
      end

      def discover_review_checklist
        discover_lerna_checklist || super
      end

      def discover_lerna_checklist
        if lerna?
          [%(
            <strong>Don't forget version and tag before publishing!</strong>
            You can do this with:<br/>
            <pre>
            lerna publish --skip-npm
            && git add -A
            && git push --follow-tags
            </pre>
          )]
        end
      end

      def lerna?
        lerna_json.exist?
      end

      def lerna_json
        file('lerna.json')
      end

      def lerna_version
        lerna_config = lerna_json.read
        JSON.parse(lerna_config)['version']
      end

      def discover_lerna_packages
        publish_lerna_packages if lerna?
      end

      def discover_deploy_steps
        discover_lerna_packages || super
      end

      def publish_lerna_packages
        return publish_independent_packages if lerna_version == 'independent'
        publish_fixed_version_packages
      end

      def publish_independent_packages
        [
          'assert-lerna-independent-version-tags',
          'publish-lerna-independent-packages',
        ]
      end

      def publish_fixed_version_packages
        check_tags = 'assert-lerna-fixed-version-tag'
        # `yarn publish` requires user input, so always use npm.
        version = lerna_version
        publish =
          "node_modules/.bin/lerna publish " \
          "--yes " \
          "--skip-git " \
          "--repo-version #{version} " \
          "--force-publish=* " \
          "--npm-tag #{dist_tag(version)}"

        [check_tags, publish]
      end
    end
  end
end
