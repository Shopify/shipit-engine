require 'json'

module Shipit
  class DeploySpec
    module LernaDiscovery
      V3 = Gem::Version.new('3.0.0')

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
          command = if lerna_semversion >= V3
            'lerna version'
          else
            %(
              lerna publish --skip-npm
              && git add -A
              && git push --follow-tags
            )
          end

          [%(
            <strong>Don't forget version and tag before publishing!</strong>
            You can do this with:<br/>
            <pre>#{command}</pre>
           )]
        end
      end

      def lerna?
        lerna_json.exist?
      end

      def lerna_legacy?
        lerna_semversion < V3
      end

      def lerna_json
        file('lerna.json')
      end

      def lerna_config
        @_lerna_config ||= JSON.parse(lerna_json.read)
      end

      def lerna_semversion
        Gem::Version.new(lerna_config['lerna'])
      end

      def lerna_version
        lerna_config['version']
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
        if lerna_legacy?
          [
            'assert-lerna-independent-version-tags',
            'publish-lerna-independent-packages',
          ]
        else
          [
            %W(
              node_modules/.bin/lerna publish
              from-git
              --yes
            ).join(" ")  
          ]
        end
      end

      def publish_fixed_version_packages
        check_tags = 'assert-lerna-fixed-version-tag'
        publish = if lerna_semversion >= LATEST_MAJOR_VERSION
          %w(
            node_modules/.bin/lerna publish
            from-git
            --yes
          ).join(" ")
        else
          # `yarn publish` requires user input, so always use npm.
          version = lerna_version
          %W(
            node_modules/.bin/lerna publish
            --yes
            --skip-git
            --repo-version #{version}
            --force-publish=*
            --npm-tag #{dist_tag(version)}
            --npm-client=npm
            --skip-npm=false
          ).join(" ")
        end

        [check_tags, publish]
      end
    end
  end
end
