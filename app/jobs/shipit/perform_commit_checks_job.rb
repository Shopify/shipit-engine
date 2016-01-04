module Shipit
  class PerformCommitChecksJob < BackgroundJob
    def perform(commit:)
      commit.checks.run
    end
  end
end
