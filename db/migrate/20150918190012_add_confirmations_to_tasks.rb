class AddConfirmationsToTasks < ActiveRecord::Migration
  def change
    add_column :tasks, :confirmations, :integer, default: 0, null: false
  end
end
