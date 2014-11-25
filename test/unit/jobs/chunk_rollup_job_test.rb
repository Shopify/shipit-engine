require 'test_helper'

class ChunkRollupJobTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:shipit)
    @job = ChunkRollupJob.new
  end

  test "#perform combines all the chunks into a new one and sets rolled_up to true" do
    expected_output = @task.chunk_output

    @job.perform(task_id: @task.id)

    @task.reload
    assert_equal 1, @task.chunks.count
    assert_equal expected_output, @task.chunk_output
    assert @task.rolled_up
  end

  test "#peform ignores non-finished jobs" do
    logger = mock
    logger.expects(:error).once
    @job.stubs(logger: logger)

    @task.update_attribute(:status, :pending)

    @job.perform(task_id: @task.id)
  end

  test "#perform ignores tasks with zero or one chunk" do
    logger = mock
    logger.expects(:error).once
    @job.stubs(logger: logger)

    @task.chunks.delete_all

    @job.perform(task_id: @task.id)
  end
end
