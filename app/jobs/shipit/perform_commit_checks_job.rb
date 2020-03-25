# typed: false
module Shipit
  class PerformCommitChecksJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :deploys

    def perform(commit:)
      commit.checks.run
    end
  end
end
