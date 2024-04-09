# frozen_string_literal: true

module Shipit
  class FetchCommitStatsJob < BackgroundJob
    queue_as :default

    def perform(commit)
      commit.fetch_stats!
    end
  end
end
