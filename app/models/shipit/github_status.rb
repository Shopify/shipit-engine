module Shipit
  module GithubStatus
    CACHE_KEY = 'github::status'.freeze

    class << self
      def status
        Rails.cache.read(CACHE_KEY)
      end

      def refresh_status
        Rails.cache.write(CACHE_KEY, Shipit.github_api.github_status)
      rescue Net::OpenTimeout, Octokit::ServerError
      end
    end
  end
end
