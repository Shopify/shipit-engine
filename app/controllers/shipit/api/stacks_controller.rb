module Shipit
  module Api
    class StacksController < BaseController
      require_permission :read, :stack, only: %i(index show)
      require_permission :write, :stack, only: %i(create)

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
      end
      def create
        @stack = Stack.new(params)
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
    end
  end
end
