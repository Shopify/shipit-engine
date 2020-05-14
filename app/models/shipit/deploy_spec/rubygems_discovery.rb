# frozen_string_literal: true
module Shipit
  class DeploySpec
    module RubygemsDiscovery
      def discover_deploy_steps
        discover_gem || super
      end

      def discover_gem
        publish_gem if gem?
      end

      def gem?
        !!gemspec
      end

      def gemspec
        Dir[file('*.gemspec').to_s].first
      end

      def publish_gem
        ["release-gem #{gemspec}"]
      end
    end
  end
end
