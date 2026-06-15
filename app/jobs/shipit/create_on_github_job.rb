# frozen_string_literal: true

module Shipit
  class CreateOnGithubJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default
    on_duplicate :drop

    # Transient Octokit::Unauthorized = GitHub installation-token propagation lag.
    # attempts: 14 (~24h) outlasts the 50m token cache (GITHUB_TOKEN_RAILS_CACHE_LIFETIME).
    # No token eviction here to avoid a remint storm across workers.
    retry_on Octokit::Unauthorized, wait: :polynomially_longer, attempts: 14 do |job, exception|
      record = job.arguments.first
      Rails.logger.warn(
        "[CreateOnGithubJob] Giving up on #{record.class.name} #{record.id} " \
          "after GitHub authentication failures: #{exception.class} #{exception.message}"
      )
    end

    # We observe that some objects regularly take longer than the default 10 seconds to create, e.g. deployments
    self.timeout = 40
    self.lock_timeout = 20

    def perform(record)
      record.reload.create_on_github!
    end
  end
end
