class ReduceTasksStatsSize < ActiveRecord::Migration
  def change
    change_column :tasks, :status, :string, null: false, default: 'pending', limit: 10
  end
end
