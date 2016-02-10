class AddAllowConcurrencyToTasks < ActiveRecord::Migration
  def change
    add_column :tasks, :allow_concurrency, :boolean, null: false, default: false
  end
end
