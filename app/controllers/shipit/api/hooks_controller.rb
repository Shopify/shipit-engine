# frozen_string_literal: true
module Shipit
  module Api
    class HooksController < BaseController
      require_permission :read, :hook, only: %i(index show)
      require_permission :write, :hook, only: %i(create update destroy)

      def index
        render_resources(hooks)
      end

      def show
        render(json: hook)
      end

      params do
        requires :delivery_url, String
        requires :events, Array[String]
        accepts :content_type, String
      end
      def create
        render_resource(hooks.create(params))
      end

      params do
        accepts :delivery_url, String
        accepts :events, Array[String]
        accepts :content_type, String
      end
      def update
        hook.update(params)
        render_resource(hook)
      end

      def destroy
        render_resource(hook.destroy)
      end

      private

      def hook
        hooks.find(params[:id])
      end

      def hooks
        Hook.where(stack_id: stack_id)
      end

      def stack_id
        stack.id if params[:stack_id].present?
      end
    end
  end
end
