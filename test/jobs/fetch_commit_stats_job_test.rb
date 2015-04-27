require 'test_helper'

class FetchCommitStatsJobTest < ActiveSupport::TestCase
  setup do
    @commit = commits(:first)
    @job = FetchCommitStatsJob.new
  end

  test "#perform call #fetch_stats! on the provided commit" do
    @commit.expects(:fetch_stats!).once
    @job.perform(@commit)
  end
end
