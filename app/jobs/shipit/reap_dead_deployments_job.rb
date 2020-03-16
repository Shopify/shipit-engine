module Shipit
  class ReapDeadDeploymentsJob < BackgroundJob
    include BackgroundJob::Unique

    ZOMBIE_STATES = %w(running aborting).freeze

    queue_as :default

    def perform
      zombie_tasks = Task.where(status: ZOMBIE_STATES).reject(&:alive?)

      Rails.logger.info("Reaping #{zombie_tasks.size} running tasks.")
      zombie_tasks.each do |task|
        Rails.logger.info("Reaping task #{task.id}: #{task.title}")
        task.report_dead!
      end
    end
  end
end
