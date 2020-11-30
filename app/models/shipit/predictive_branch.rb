# frozen_string_literal: true

module Shipit
  class PredictiveBranch < Task

    belongs_to :predictive_build

    after_commit :broadcast_update

    # delegate :broadcast_update, to: :stack

    def async_refresh_deployed_revision

    end

    def async_update_estimated_deploy_duration

    end

  end
end
