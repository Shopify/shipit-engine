class AddEnvToTasks < ActiveRecord::Migration
  def change
    add_column :tasks, :env, :text
  end
end
