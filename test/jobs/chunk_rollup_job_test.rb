# frozen_string_literal: true

require 'test_helper'

module Shipit
  class ChunkRollupJobTest < ActiveSupport::TestCase
    setup do
      @task = shipit_tasks(:shipit)
      @task.write("dummy output")
      @job = ChunkRollupJob.new
    end

    test "#perform combines all the chunks into a output and sets rolled_up to true" do
      expected_output = @task.chunk_output
      assert @task.output.blank?

      @job.perform(@task)

      @task.reload
      assert @task.output.present?
      assert_equal expected_output, @task.chunk_output
      assert @task.rolled_up
      assert_nil Shipit.redis.get(@task.send(:output_key))
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

    test "#perform takes into account data still in the DB" do
      output_chunks = Shipit::OutputChunk.create(text: "DB output", task: @task)
      expected_output = [output_chunks.text, @task.chunk_output].join("\n")

      @job.perform(@task)

      @task.reload
      assert_equal expected_output, @task.chunk_output
      assert @task.rolled_up
      assert_empty Shipit::OutputChunk.where(task: @task)
      assert_nil Shipit.redis.get(@task.send(:output_key))
    end
  end
end
