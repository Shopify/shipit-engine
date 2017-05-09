class AddConfirmationsToTasks < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :confirmations, :integer, default: 0, null: false
  end
end
