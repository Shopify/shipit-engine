module Api
  class DeploysController < BaseController
    params do
      requires :sha, String, length: {in: 6..40}
      accepts :force, Boolean, default: false
    end
    def create
      commit = stack.commits.by_sha(params.sha) || param_error!(:sha, 'Unknown revision')
      param_error!(:force, "Can't deploy a locked stack") if !params.force && stack.locked?
      render_resource stack.trigger_deploy(commit, current_user), status: :accepted
    end

    private

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
