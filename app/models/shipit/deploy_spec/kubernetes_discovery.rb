module Shipit
  class DeploySpec
    module KubernetesDiscovery
      def discover_deploy_steps
        discover_kubernetes || super
      end

      def discover_rollback_steps
        discover_kubernetes || super
      end

      private

      def discover_kubernetes
        return unless kube_config.present?

        cmd = ["kubernetes-deploy"]
        if kube_config['template_dir']
          cmd << '--template-dir'
          cmd << kube_config['template_dir']
        end

        cmd << kube_config['namespace']
        cmd << kube_config['context']

        [Shellwords.join(cmd)]
      end

      def kube_config
        @kube_config ||= config('kubernetes') || {}
      end
    end
  end
end
