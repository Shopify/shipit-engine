module Shipit
  class DeploySpec
    module KubernetesDiscovery
      def discover_deploy_steps
        discover_kubernetes || super
      end

      def discover_rollback_steps
        discover_kubernetes || super
      end

      def discover_machine_env
        env = super
        env = env.merge('K8S_TEMPLATE_FOLDER' => kube_config['template_dir']) if kube_config['template_dir']
        env
      end

      private

      def discover_kubernetes
        return unless kube_config.present?

        [
          Shellwords.join([
            'kubernetes-deploy',
            kube_config['namespace'],
            kube_config['context'],
          ]),
        ]
      end

      def kube_config
        @kube_config ||= config('kubernetes') || {}
      end
    end
  end
end
