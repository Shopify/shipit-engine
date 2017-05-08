class AddAllowConcurrencyToTasks < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :allow_concurrency, :boolean, null: false, default: false
  end
end
