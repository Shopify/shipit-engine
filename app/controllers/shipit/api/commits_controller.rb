# frozen_string_literal: true
module Shipit
  module Api
    class CommitsController < BaseController
      require_permission :read, :stack

      def index
        commits = stack.commits.reachable.includes(:statuses)
        if params[:undeployed]
          commits = commits.newer_than(stack.last_deployed_commit)
        end

        render_resources(commits)
      end
    end
  end
end
