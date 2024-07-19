# frozen_string_literal: true
module Shipit
  class BackgroundJob < ActiveJob::Base
    class << self
      attr_accessor :timeout
    end

    # Write actions can sometimes fail intermittently, particulary for large and/or busy repositories
    retry_on(Octokit::ServerError)

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
