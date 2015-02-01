class ChunkRollupJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::DeployExclusive

  def perform
    return unless task_finished?
    return unless task_has_many_chunks?

    task.transaction do
      output = task.chunk_output
      task.chunks.delete_all
      task.write(output)
      task.update!(rolled_up: true)
    end
  end

  def task_finished?
    return true if task.finished?
    logger.error("Task ##{task.id} is not finished (current state: #{task.status}). Aborting.")
    false
  end

  def task_has_many_chunks?
    chunk_count = task.chunks.count
    return true if chunk_count > 1
    logger.error("Task ##{task.id} has only #{chunk_count} chunks. Aborting.")
  end

  def task
    @task ||= Task.find(params[:task_id])
  end
end
