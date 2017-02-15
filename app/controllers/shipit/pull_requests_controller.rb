module Shipit
  class PullRequestsController < ShipitController
    def index
      @pull_requests = stack.pull_requests.to_be_merged
    end

    private

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
