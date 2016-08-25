module Shipit
  module Api
    class StacksController < BaseController
      require_permission :read, :stack, only: %i(index show)
      require_permission :write, :stack, only: %i(create)

      def index
        render_resources stacks
      end

      def create
        @stack = Stack.new(create_params)
        @stack.save!
        render_resource @stack
      end

      def show
        render_resource stack
      end

      private

      def stack
        @stack ||= stacks.from_param!(params[:id])
      end

      def create_params
        params.require(:stack).permit(:repo_name, :repo_owner, :environment, :branch, :deploy_url, :ignore_ci)
      end
    end
  end
end
