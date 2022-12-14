# frozen_string_literal: true
module Shipit
  module Api
    class RollbacksController < BaseController
      require_permission :deploy, :stack

      params do
        requires :sha, String, length: { in: 6..40 }
        accepts :force, Boolean, default: false
        accepts :env, Hash, default: {}
        accepts :lock, Boolean, default: true
        accepts :safeties_enforced, Boolean, default: false
      end
      def create
        commit = stack.commits.by_sha(params.sha) || param_error!(:sha, 'Unknown revision')
        param_error!(:force, "Can't rollback a locked stack") if !params.force && stack.locked?
        deploy = stack.deploys.find_by(until_commit: commit) || param_error!(:sha, 'Cant find associated deploy')
        deploy_env = stack.filter_deploy_envs(params.env)

        response = nil
        if !params.force && stack.active_task?
          param_error!(:force, "Can't rollback, deploy in progress")
        elsif stack.active_task?
          active_task = stack.active_task
          active_task.abort!(aborted_by: current_user, rollback_once_aborted_to: deploy, rollback_once_aborted: true)
          response = active_task
        else
          response = deploy.trigger_rollback(current_user, env: deploy_env, force: params.force, lock: params.lock,
            safeties_enforced: params.safeties_enforced)
        end

        render_resource(response, status: :accepted)
      end
    end
  end
end
