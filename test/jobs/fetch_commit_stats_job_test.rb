# frozen_string_literal: true

require 'test_helper'

module Shipit
  class FetchCommitStatsJobTest < ActiveSupport::TestCase
    setup do
      @commit = shipit_commits(:first)
      @job = FetchCommitStatsJob.new
    end

    test "#perform call #fetch_stats! on the provided commit" do
      @commit.expects(:fetch_stats!).once
      @job.perform(@commit)
    end
  end
end
