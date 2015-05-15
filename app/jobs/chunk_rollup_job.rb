class ChunkRollupJob < BackgroundJob
  include BackgroundJob::Unique

  queue_as :default

  def perform(task)
    unless task.finished?
      logger.error("Task ##{task.id} is not finished (current state: #{task.status}). Aborting.")
      return
    end

    chunk_count = task.chunks.count

    unless chunk_count > 1
      logger.error("Task ##{task.id} only has #{chunk_count} chunks. Aborting.")
      return
    end

    output = task.chunk_output

    ActiveRecord::Base.transaction do
      OutputChunk.where(id: task.chunks.ids).delete_all
      task.write(output)
      task.update_attribute(:rolled_up, true)
    end
  end
end
