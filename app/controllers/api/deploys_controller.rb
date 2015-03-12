module Api
  class DeploysController < BaseController
    params do
      requires :sha, String
      validates :sha, length: {in: 6..40}
    end
    def create
      commit = stack.commits.by_sha(params.sha) || param_error!(:sha, 'Unknown revision')
      render json: stack.trigger_deploy(commit, current_user), status: :accepted
    end

    private

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
