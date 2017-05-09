class ImproveIndexesOnTasks < ActiveRecord::Migration[4.2]
  def change
    add_index :tasks, [:type, :stack_id, :status], name: :index_tasks_by_stack_and_status
    add_index :tasks, [:type, :stack_id, :parent_id], name: :index_tasks_by_stack_and_parent
  end
end
