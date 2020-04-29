# frozen_string_literal: true
module Shipit
  class UpdateEstimatedDeployDurationJob < BackgroundJob
    queue_as :default

    def perform(stack)
      stack.update_estimated_deploy_duration!
    end
  end
end
