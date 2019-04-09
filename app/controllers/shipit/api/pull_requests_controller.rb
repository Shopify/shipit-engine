module Shipit
  module Api
    class PullRequestsController < BaseController
      require_permission :read, :stack
      require_permission :deploy, :stack, only: %i(update destroy)

      def index
        render_resources stack.pull_requests.includes(:head).order(id: :desc)
      end

      def show
        render_resource stack.pull_requests.find_by!(number: params[:id])
      end

      def update
        pull_request = PullRequest.request_merge!(stack, params[:id], current_user, params[:unsafe_to_rollback])
        if pull_request.waiting?
          head :accepted
        elsif pull_request.merged?
          render status: :method_not_allowed, json: {
            message: "This pull request was already merged.",
          }
        else
          raise "Pull Request is neither waiting nor merged, this should be impossible"
        end
      end

      def destroy
        if pull_request = stack.pull_requests.where(number: params[:id]).first
          pull_request.cancel! if pull_request.waiting?
        end
        head :no_content
      end
    end
  end
end
