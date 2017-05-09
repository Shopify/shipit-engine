class ReorderActiveTasksIndex < ActiveRecord::Migration[4.2]
  def change
    remove_index :tasks, name: :index_active_tasks
    add_index :tasks, %i(stack_id allow_concurrency status), name: :index_active_tasks
    remove_index :tasks, :stack_id # now useless since `index_active_tasks` starts by `stack_id`
  end
end
