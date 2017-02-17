module Shipit
  module Api
    class CcmenuController < BaseController
      require_permission :read, :stack

      class NoDeploy
        def id
          0
        end

        def ended_at
          Time.now.utc
        end

        def status
          false
        end

        alias_method :running?, :status
        alias_method :failed?, :status
        alias_method :error?, :status
        alias_method :success?, :status
      end

      def show
        latest_deploy = stack.deploys.first || NoDeploy.new
        render 'shipit/ccmenu/project.xml.builder', formats: [:xml], locals: {stack: stack, deploy: latest_deploy}
      end

      private

      def stack
        @stack ||= Stack.from_param!(params[:stack_id])
      end
    end
  end
end
