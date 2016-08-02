module Shipit
  class PerformCommitChecksJob < BackgroundJob
    include BackgroundJob::Unique

    def perform(commit:)
      commit.checks.run
    end
  end
end
