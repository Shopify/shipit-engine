class ReduceTasksTypeSize < ActiveRecord::Migration
  def change
    change_column :tasks, :type, :string, limit: 10, null: true
  end
end
