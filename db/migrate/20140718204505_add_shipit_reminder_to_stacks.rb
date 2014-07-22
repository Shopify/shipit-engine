class AddShipitReminderToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :shipit_reminder, :boolean, null: false, default: false
  end
end
