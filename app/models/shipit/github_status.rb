module Shipit
  class GithubStatus
    class << self
      def refresh_status
        Rails.cache.fetch('github::status') do
          Shipit.github_api.github_status
        end
      end
    end
  end
end
