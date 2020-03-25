# typed: false
class ReduceTasksStatsSize < ActiveRecord::Migration[4.2]
  def change
    change_column :tasks, :status, :string, null: false, default: 'pending', limit: 10
  end
end
