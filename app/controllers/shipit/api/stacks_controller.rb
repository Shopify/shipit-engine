module Shipit
  module Api
    class StacksController < BaseController
      require_permission :read, :stack, only: %i(index show)
      require_permission :write, :stack, only: %i(create destroy)

      def index
        render_resources stacks
      end

      params do
        requires :repo_owner, String
        requires :repo_name, String
        accepts :environment, String
        accepts :branch, String
        accepts :deploy_url, String
        accepts :ignore_ci, Boolean
        accepts :merge_queue_enabled, Boolean
      end
      def create
        render_resource Stack.create(params)
      end

      def show
        render_resource stack
      end

      def destroy
        stack.schedule_for_destroy!
        head :accepted
      end

      private

      def stack
        @stack ||= stacks.from_param!(params[:id])
      end
    end
  end
end
