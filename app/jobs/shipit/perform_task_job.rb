# frozen_string_literal: true
module Shipit
  class PerformTaskJob < BackgroundJob
    queue_as :deploys

    def perform(task, execution_strategy: Shipit::TaskExecutionStrategy::Default)
      execution_strategy
        .new(task)
        .execute
    end

    attr_accessor :execution_strategy
  end
end
