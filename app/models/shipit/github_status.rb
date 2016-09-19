module Shipit
  module GithubStatus
    CACHE_KEY = 'github::status'.freeze

    class << self
      def status
        Rails.cache.read(CACHE_KEY)
      end

      def refresh_status
        Rails.cache.fetch(CACHE_KEY) do
          Shipit.github_api.github_status
        end
      end
    end
  end
end
