# typed: false
class FixTasksIndexByStatus < ActiveRecord::Migration[5.1]
  def up
    remove_index :tasks, name: :index_tasks_by_stack_and_status
    add_index :tasks, [:stack_id, :status, :type], name: :index_tasks_by_stack_and_status
  end

  def down
    remove_index :tasks, name: :index_tasks_by_stack_and_status
    add_index :tasks, [:type, :stack_id, :status], name: :index_tasks_by_stack_and_status
  end
end
