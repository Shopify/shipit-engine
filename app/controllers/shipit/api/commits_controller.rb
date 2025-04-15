# frozen_string_literal: true

module Shipit
  module Api
    class CommitsController < BaseController
      require_permission :read, :stack

      def index
        commits = stack.commits.reachable.includes(:statuses)
        commits = commits.newer_than(stack.last_deployed_commit) if params[:undeployed]

        render_resources(commits)
      end
    end
  end
end
