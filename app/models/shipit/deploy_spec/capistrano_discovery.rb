# frozen_string_literal: true

module Shipit
  class DeploySpec
    module CapistranoDiscovery
      def discover_deploy_steps
        discover_capistrano || super
      end

      def discover_rollback_steps
        discover_capistrano_rollback || super
      end

      def discover_capistrano
        [cap('deploy')] if capistrano?
      end

      def discover_capistrano_rollback
        [cap('deploy:rollback')] if capistrano?
      end

      def cap(command)
        bundle_exec("cap $ENVIRONMENT #{command}")
      end

      def capistrano?
        file('Capfile').exist?
      end
    end
  end
end
