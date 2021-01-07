# frozen_string_literal: true

module Shipit
  class PredictiveBranchTask < Task

    belongs_to :predictive_branch

    # after_commit :broadcast_update

    # delegate :broadcast_update, to: :stack

    def report_complete!
      super
      predictive_branch.update_status(self )
    end

    def report_failure!(error)
      super
      predictive_branch.update_status(self )
    end

    def report_timeout!(_error)
      super
      predictive_branch.update_status(self )
    end

    def report_error!(error)
      super
      predictive_branch.update_status(self )
    end

    def report_dead!
      super
      predictive_branch.update_status(self )
    end

    def async_refresh_deployed_revision

    end

    def async_update_estimated_deploy_duration

    end

  end
end
