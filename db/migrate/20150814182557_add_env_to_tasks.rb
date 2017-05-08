class AddEnvToTasks < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :env, :text
  end
end
