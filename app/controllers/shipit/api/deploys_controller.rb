# frozen_string_literal: true
module Shipit
  module Api
    class DeploysController < BaseController
      require_permission :deploy, :stack

      def index
        render_resources(stack.deploys_and_rollbacks)
      end

      params do
        requires :sha, String, length: { in: 6..40 }
        accepts :force, Boolean, default: false
        accepts :require_ci, Boolean, default: false
        accepts :env, Hash, default: {}
      end
      def create
        commit = stack.commits.by_sha(params.sha) || param_error!(:sha, 'Unknown revision')
        param_error!(:force, "Can't deploy a locked stack") if !params.force && stack.locked?
        param_error!(:require_ci, "Commit is not deployable") if params.require_ci && !commit.deployable?
        deploy = stack.trigger_deploy(commit, current_user, env: params.env, force: params.force)
        render_resource(deploy, status: :accepted)
      end
    end
  end
end
