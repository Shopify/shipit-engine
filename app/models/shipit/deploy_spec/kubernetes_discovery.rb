module Shipit
  class DeploySpec
    module KubernetesDiscovery
      def discover_deploy_steps
        discover_kubernetes || super
      end

      def discover_rollback_steps
        discover_kubernetes || super
      end

      def discover_task_definitions
        if kube_config.present?
          {
            'restart' => {
              'action' => "Restart application",
              'description' => "Simulates a rollout of Kubernetes deployments by using kubernetes-restart utility",
              'steps' => [kubernetes_restart_cmd],
              'bundler' => false,
            },
          }
        else
          super
        end
      end

      private

      def discover_kubernetes
        return unless kube_config.present?

        cmd = ["kubernetes-deploy"]
        if kube_config['template_dir']
          cmd << '--template-dir'
          cmd << kube_config['template_dir']
        end

        cmd << kube_config.fetch('namespace')
        cmd << kube_config.fetch('context')

        [Shellwords.join(cmd)]
      end

      def kube_config
        @kube_config ||= config('kubernetes') || {}
      end

      def kubernetes_restart_cmd
        Shellwords.join([
          "kubernetes-restart",
          kube_config.fetch('namespace'),
          kube_config.fetch('context'),
        ])
      end
    end
  end
end
