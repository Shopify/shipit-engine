# frozen_string_literal: true
require 'test_helper'

module Shipit
  class ChunkRollupJobTest < ActiveSupport::TestCase
    setup do
      @task = shipit_tasks(:shipit)
      @job = ChunkRollupJob.new
    end

    test "#perform combines all the chunks into a output and sets rolled_up to true" do
      expected_output = @task.chunk_output
      assert @task.output.blank?

      @job.perform(@task)

      @task.reload
      assert_equal 0, @task.chunks.count
      assert @task.output.present?
      assert_equal expected_output, @task.chunk_output
      assert @task.rolled_up
    end

    test "#peform ignores non-finished jobs" do
      logger = mock
      logger.expects(:error).once
      @job.stubs(logger: logger)

      @task.update_attribute(:status, :pending)

      @job.perform(@task)
    end

    test "#perform ignores tasks already rolled up" do
      logger = mock
      logger.expects(:error).once
      @job.stubs(logger: logger)

      @task.rolled_up = true

      @job.perform(@task)
    end
  end
end
