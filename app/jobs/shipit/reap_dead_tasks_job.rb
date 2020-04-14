module Shipit
  class ReapDeadTasksJob < BackgroundJob
    include BackgroundJob::Unique

    ZOMBIE_STATES = %w(running aborting).freeze

    queue_as :default

    def perform
      Rails.logger.info("Reaping #{zombie_tasks.size} running tasks.")
      zombie_tasks.each do |task|
        Rails.logger.info("Reaping task #{task.id}: #{task.title}")
        task.report_dead!
      end
    end

    MINUTES_TO_CONSIDER_TASK_RECENT = 5
    private_constant :MINUTES_TO_CONSIDER_TASK_RECENT
    def self.recently_created_at
      MINUTES_TO_CONSIDER_TASK_RECENT.minutes.ago
    end

    private

    def zombie_tasks
      @zombie_tasks ||= Task
                        .where(status: ZOMBIE_STATES)
                        .where(
                          "created_at <= :recently",
                          recently: recently_created_at,
                        )
                        .reject(&:alive?)
    end

    def recently_created_at
      self.class.recently_created_at
    end
  end
end
