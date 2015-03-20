class RemoveStacksReminderUrls < ActiveRecord::Migration
  def change
    remove_column :stacks, :reminder_url
  end
end
