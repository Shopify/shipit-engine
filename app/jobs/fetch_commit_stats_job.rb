class FetchCommitStatsJob < BackgroundJob
  queue_as :default

  def perform(params)
    commit = Commit.find(params[:commit_id])
    commit.fetch_stats!
  end
end
