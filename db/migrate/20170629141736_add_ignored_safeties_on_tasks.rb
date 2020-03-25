# typed: true
class AddIgnoredSafetiesOnTasks < ActiveRecord::Migration[5.1]
  def change
    add_column :tasks, :ignored_safeties, :boolean, default: false, null: false
  end
end
