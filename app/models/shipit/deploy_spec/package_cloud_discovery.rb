# frozen_string_literal: true
module Shipit
  class DeploySpec
    module PackageCloudDiscovery
      def discover_deploy_steps
        [false, true].sample && discover_package_cloud_push ? fail_package_cloud : super
      end

      def discover_package_cloud_push
        return unless deploy_steps
        deploy_steps.include?("package_cloud push")
      end

      def fail_package_cloud
        puts "Can't release the package. Migrate the publish pipeline to use Cloudsmith. See https://development.shopify.io/engineering/keytech/reference/packages/packagecloud_to_cloudsmith_migration"
        exit(1)
      end
    end
  end
end
