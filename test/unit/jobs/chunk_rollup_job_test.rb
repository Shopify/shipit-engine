require 'test_helper'

class ChunkRollupJobTest < ActiveSupport::TestCase
  setup do
    @deploy = deploys(:shipit)
    @job = ChunkRollupJob.new
  end

  test "#perform combines all the chunks into a new one" do
    expected_output = @deploy.chunk_output

    @job.perform(deploy_id: @deploy.id)

    assert_equal 1, @deploy.chunks.count
    assert_equal expected_output, @deploy.chunk_output
  end

  test "#peform ignores non-finished jobs" do
    logger = mock
    logger.expects(:error).once
    @job.stubs(logger: logger)

    @deploy.update_attribute(:status, :pending)

    @job.perform(deploy_id: @deploy.id)
  end

  test "#perform ignores deploys with zero or one chunk" do
    logger = mock
    logger.expects(:error).once
    @job.stubs(logger: logger)

    @deploy.chunks.delete_all

    @job.perform(deploy_id: @deploy.id)
  end
end
