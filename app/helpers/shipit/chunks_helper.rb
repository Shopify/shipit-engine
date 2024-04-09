# frozen_string_literal: true

module Shipit
  module ChunksHelper
    def next_chunks_url(task, last_byte: 0)
      return if task.finished?
      tail_stack_task_path(task.stack, task, last_byte: last_byte)
    end
  end
end
