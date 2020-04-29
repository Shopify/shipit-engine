# frozen_string_literal: true
module Shipit
  class ReapDeadTasksJob < BackgroundJob
    include BackgroundJob::Unique
    queue_as :default

    def perform
      Rails.logger.info("Reaping #{zombie_tasks.size} running tasks.")
      zombie_tasks.each do |task|
        Rails.logger.info("Reaping task #{task.id}: #{task.title}")
        task.report_dead!
      end
    end

    private

    def zombie_tasks
      @zombie_tasks ||= Task.zombies
    end
  end
end
