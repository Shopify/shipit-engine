class ReduceTasksTypeSize < ActiveRecord::Migration[4.2]
  def change
    change_column :tasks, :type, :string, limit: 10, null: true
  end
end
