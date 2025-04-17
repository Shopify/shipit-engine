# frozen_string_literal: true

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
              'steps' => [kubernetes_restart_cmd]
            }
          }.merge!(super)
        else
          super
        end
      end

      private

      def timeout_duration
        duration = kube_config.fetch('timeout', '900s')
        Duration.parse(duration).to_i if duration.present?
      end

      def discover_kubernetes
        return if kube_config.blank?

        cmd = ["kubernetes-deploy"]
        cmd += ["--max-watch-seconds", timeout_duration] if timeout_duration
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
        cmd = [
          "kubernetes-restart",
          kube_config.fetch('namespace'),
          kube_config.fetch('context')
        ]
        cmd += ["--max-watch-seconds", timeout_duration] if timeout_duration
        Shellwords.join(cmd)
      end
    end
  end
end
