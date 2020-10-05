# frozen_string_literal: true
module Shipit
  class PerformTaskJob < BackgroundJob
    queue_as :deploys

    def perform(task)
      Shipit
        .task_execution_strategy
        .new(task)
        .execute
    end
  end
end
