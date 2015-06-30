class PerformCommitChecksJob < BackgroundJob
  def perform(commit:)
    commit.checks.run
  end
end
