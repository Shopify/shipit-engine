module Shipit
  module Api
    class DeploysController < BaseController
      require_permission :deploy, :stack


      def deploys
        render_resources stack.deploys_and_rollbacks
      end

      params do
        requires :sha, String, length: {in: 6..40}
        accepts :force, Boolean, default: false
        accepts :env, Hash, default: {}
      end
      def create
        commit = stack.commits.by_sha(params.sha) || param_error!(:sha, 'Unknown revision')
        param_error!(:force, "Can't deploy a locked stack") if !params.force && stack.locked?
        deploy = stack.trigger_deploy(commit, current_user, env: params.env, force: params.force)
        render_resource deploy, status: :accepted
      end
    end
  end
end
