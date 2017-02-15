module Shipit
  class PullRequestsController < ShipitController
    def index
      @pull_requests = stack.pull_requests.to_be_merged
    end

    def destroy
      pull_request = stack.pull_requests.find(params[:id])
      pull_request.cancel!
      flash[:success] = 'Merge canceled'
      redirect_to stack_pull_requests_path
    end

    private

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
