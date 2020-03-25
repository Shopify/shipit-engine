# typed: false
class AddRollbackWhenCompleteOnTask < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :rollback_once_aborted, :boolean, default: false, null: false
  end
end
