require 'test_helper'

class UniqueJobTest < ActiveSupport::TestCase
  test "the lock key contains the job type" do
    task = tasks(:shipit_restart)
    job_a = ChunkRollupJob.new(task)
    job_b = GithubSyncJob.new(task)

    called = false
    job_a.acquire_lock do
      job_b.acquire_lock do
        called = true
      end
    end
    assert called
  end
end
