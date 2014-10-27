module ChunksHelper
  def next_chunks_url(task)
    return if task.finished?
    tail_stack_task_chunks_path(task.stack, task, last_id: task.chunks.last)
  end
end
