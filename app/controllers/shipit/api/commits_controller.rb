module Shipit
  module Api
    class CommitsController < BaseController
      require_permission :read, :stack

      def index
        render_resources stack.commits.reachable.includes(:statuses)
      end

      def undeployed
        stack.undeployed_commits do |undeployed_commits|
          render_resources undeployed_commits
        end
      end
    end
  end
end
