class FetchCommitStatsJob < BackgroundJob
  @queue = :default

  self.timeout = 60

  def perform(params)
    commit = Commit.find(params[:commit_id])
    commit.fetch_stats!
  end
end
