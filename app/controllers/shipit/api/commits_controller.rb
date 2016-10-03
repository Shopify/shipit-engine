module Shipit
  module Api
    class CommitsController < BaseController
      require_permission :read, :stack

      def index
        render_resources stack.commits.reachable.includes(:statuses)
      end
    end
  end
end
