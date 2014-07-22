class AddReminderUrlToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :reminder_url, :string
  end
end
