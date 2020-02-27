class AddEmergencyModeOnTasks < ActiveRecord::Migration[6.0]
  def change
    add_column :tasks, :emergency_mode, :boolean, default: false, null: false
  end
end
