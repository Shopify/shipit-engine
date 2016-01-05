module Shipit
  module TasksHelper
    def task_description(task)
      if task.class == Task
        task.definition.action
      else
        t("#{task.class.name.demodulize.underscore.pluralize}.description", sha: task.until_commit.short_sha)
      end
    end
  end
end
