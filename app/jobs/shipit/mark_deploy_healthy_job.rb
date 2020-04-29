# frozen_string_literal: true
module Shipit
  class MarkDeployHealthyJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    def perform(deploy)
      return unless deploy.validating?

      deploy.report_healthy!(description: "No issues were signalled after #{deploy.stack.release_status_delay}")
    end
  end
end
