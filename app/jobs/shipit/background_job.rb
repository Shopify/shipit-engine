# frozen_string_literal: true

module Shipit
  class BackgroundJob < ActiveJob::Base
    class << self
      attr_accessor :timeout
    end

    DEFAULT_RETRY_TIME_IN_SECONDS = 30

    # Allow hours for GitHub outages to recover while still raising after the last attempt.
    retry_on(Octokit::ServerError, wait: :polynomially_longer, attempts: 10)

    rescue_from(Octokit::TooManyRequests, Octokit::AbuseDetected) do |exception|
      retry_job wait: exception.response_headers.fetch("Retry-After", DEFAULT_RETRY_TIME_IN_SECONDS).to_i.seconds
    end

    def perform(*)
      with_timeout do
        super
      end
    end

    private

    def with_timeout(&block)
      return yield unless timeout

      Timeout.timeout(timeout, &block)
    end

    def logger
      Rails.logger
    end
  end
end
