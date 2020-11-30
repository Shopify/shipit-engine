# frozen_string_literal: true

module Shipit
  class PredictiveBuild < Record
    belongs_to :pipeline
    has_many :predictive_branches

    def build_predictive_branch(user, stack, env: nil, allow_concurrency: true)
      predictive_branches.build(
          user_id: user.id,
          # TODO:
          # until_commit: until_commit,
          # since_commit: since_commit,
          #
          env: filter_deploy_envs(env&.to_h || {}),
          allow_concurrency: allow_concurrency,
      )
    end

    def trigger_build_predictive_branch(*args, **kwargs)
      run_now = kwargs.delete(:run_now)
      predictive_branch = with_lock do
        predictive_branch = build_predictive_branch(*args, **kwargs)
        predictive_branch.save!
        predictive_branch
      end
      run_now ? predictive_branch.run_now! : predictive_branch.enqueue
      predictive_branch
    end
  end
end
