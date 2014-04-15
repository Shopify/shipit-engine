class ChunkRollupJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::DeployExclusive

  def perform(params)
    @deploy = Deploy.find(params[:deploy_id])

    unless @deploy.pending?
      logger.error("Deploy ##{@deploy.id} already in `#{@deploy.status}` state. Aborting.")
      return
    end

    chunk_count = @deploy.chunks.count

    unless chunk_count > 1
      logger.error("Deploy ##{@deploy.id} only has #{chunk_count} chunks. Aborting.")
      return
    end

    output = @deploy.chunk_output

    ActiveRecord::Base.transaction do
      @deploy.chunks.delete_all
      @deploy.write(output)
    end
  end
end
