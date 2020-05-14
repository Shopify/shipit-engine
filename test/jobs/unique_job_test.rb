# frozen_string_literal: true
require 'test_helper'

module Shipit
  class UniqueJobTest < ActiveSupport::TestCase
    test "the lock key contains the job type" do
      task = shipit_tasks(:shipit_restart)
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

    test "the lock key is serialized" do
      task = shipit_tasks(:shipit_restart)
      job = ChunkRollupJob.new(task)
      key = %(Shipit::ChunkRollupJob-{"_aj_globalid"=>"gid://shipit/Shipit::Task/#{task.id}"})
      assert_equal key, job.lock_key(*job.arguments)
    end
  end
end
