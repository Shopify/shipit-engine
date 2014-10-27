class AddDefinitionToTasks < ActiveRecord::Migration
  def change
    add_column :tasks, :definition, :text, null: true
  end
end
