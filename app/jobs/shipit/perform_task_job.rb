# frozen_string_literal: true
module Shipit
  class PerformTaskJob < BackgroundJob
    queue_as :deploys

    def perform(task)
      Shipit::TaskExecutionStrategy
        .for(task)
        .execute
    end

    attr_accessor :execution_strategy
  end
end
