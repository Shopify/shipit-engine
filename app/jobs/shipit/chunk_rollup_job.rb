module Shipit
  class ChunkRollupJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    self.timeout = 60
    self.lock_timeout = 30

    def perform(task)
      unless task.finished?
        logger.error("Task ##{task.id} is not finished (current state: #{task.status}). Aborting.")
        return
      end

      if task.rolled_up?
        logger.error("Task ##{task.id} has already been rolled up. Aborting.")
        return
      end

      task.rollup_chunks
    end
  end
end
