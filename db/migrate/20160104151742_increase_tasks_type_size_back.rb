class IncreaseTasksTypeSizeBack < ActiveRecord::Migration
  def change
    change_column :tasks, :type, :string, limit: 20, null: true
  end
end
