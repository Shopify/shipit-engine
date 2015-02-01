class DeleteOrphanRecords < ActiveRecord::Migration
  def change
    stack_ids = Stack.pluck(:id)
    Task.transaction do
      tasks_count = Task.where.not(stack_id: stack_ids).delete_all
      commits_count = Commit.where.not(stack_id: stack_ids).delete_all
      chunks_count = OutputChunk.where.not(task_id: Task.pluck(:id)).delete_all
      hooks_count = Webhook.where.not(stack_id: stack_ids).delete_all
      puts "Deleted: tasks=#{tasks_count} commits=#{commits_count} chunks=#{chunks_count} hooks=#{hooks_count}"
    end
  end
end
