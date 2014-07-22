class AddReminderCommandToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :reminder_command, :text, null: true, default: nil
  end
end
