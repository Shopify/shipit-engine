# frozen_string_literal: true

module Shipit
  module Api
    class MergeRequestsController < BaseController
      require_permission :read, :stack
      require_permission :deploy, :stack, only: %i(update destroy)

      def index
        render_resources(stack.merge_requests.includes(:head).order(id: :desc))
      end

      def show
        render_resource(stack.merge_requests.find_by!(number: params[:id]))
      end

      def update
        merge_request = MergeRequest.request_merge!(stack, params[:id], current_user)
        if merge_request.waiting?
          head(:accepted)
        elsif merge_request.merged?
          render(status: :method_not_allowed, json: {
            message: "This pull request was already merged.",
          })
        else
          raise "Pull Request is neither waiting nor merged, this should be impossible"
        end
      end

      def destroy
        if merge_request = stack.merge_requests.where(number: params[:id]).first
          merge_request.cancel! if merge_request.waiting?
        end
        head(:no_content)
      end
    end
  end
end
