class AddRetryAttemptToTasks < ActiveRecord::Migration[6.0]
  def change
    add_column :tasks, :retry_attempt, :integer, null: false, default: 0
  end
end
